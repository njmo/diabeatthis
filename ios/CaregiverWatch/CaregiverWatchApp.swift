import Charts
import SwiftUI
import UserNotifications
import WatchConnectivity
import WatchKit

@main
struct CaregiverWatchApp: App {
  @StateObject private var connection = PhoneConnection()
  @WKApplicationDelegateAdaptor private var delegate: WatchNotificationDelegate

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        RequestList(delegate: delegate)
      }
      .environmentObject(connection)
    }
  }
}

final class WatchNotificationDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate,
                                       ObservableObject {
  @Published var selectedRequestId: String?

  func applicationDidFinishLaunching() {
    UNUserNotificationCenter.current().delegate = self
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completion: @escaping () -> Void) {
    if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
       let id = response.notification.request.content.userInfo["requestId"] as? String,
       id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil {
      DispatchQueue.main.async { self.selectedRequestId = id }
    }
    completion()
  }
}

enum WatchError: Error {
  case unavailable
  case expired
  case phoneUnreachable
  case phoneNotReady
  case caregiverRequired
  case familyPairingRequired
  case caregiverRequestsDisabled
  case inboxUnavailable

  var listMessage: LocalizedStringKey {
    switch self {
    case .phoneUnreachable:
      return "Cannot connect to the paired iPhone."
    case .phoneNotReady:
      return "Open Diabeatthis on your iPhone and try again."
    case .caregiverRequired:
      return "Switch Diabeatthis on your iPhone to caregiver mode."
    case .familyPairingRequired:
      return "Pair your child's account in Diabeatthis on your iPhone first."
    case .caregiverRequestsDisabled:
      return "Enable meal requests in Diabeatthis on your iPhone."
    case .inboxUnavailable:
      return "Could not load meal requests. Try again."
    default:
      return "Could not load meal requests. Try again."
    }
  }
}

final class PhoneConnection: NSObject, ObservableObject, WCSessionDelegate {
  override init() {
    super.init()
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }

  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

  func exchange(_ action: String, request: String? = nil,
                fields: [String: Any] = [:]) async throws -> [String: Any] {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      throw WatchError.phoneUnreachable
    }
    var message = fields
    message["version"] = 1
    message["action"] = action
    message["requestId"] = request
    return try await withCheckedThrowingContinuation { continuation in
      session.sendMessage(message, replyHandler: { reply in
        let payload = (reply["payload"] as? Data)
          .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? reply
        switch payload["status"] as? String {
        case "ok": continuation.resume(returning: payload)
        case "expired": continuation.resume(throwing: WatchError.expired)
        case "phoneNotReady": continuation.resume(throwing: WatchError.phoneNotReady)
        case "caregiverRequired": continuation.resume(throwing: WatchError.caregiverRequired)
        case "familyPairingRequired": continuation.resume(throwing: WatchError.familyPairingRequired)
        case "caregiverRequestsDisabled": continuation.resume(throwing: WatchError.caregiverRequestsDisabled)
        case "inboxUnavailable": continuation.resume(throwing: WatchError.inboxUnavailable)
        default: continuation.resume(throwing: WatchError.unavailable)
        }
      }, errorHandler: { _ in
        continuation.resume(throwing: WatchError.phoneUnreachable)
      })
    }
  }
}

struct MealRequest: Identifiable, Hashable {
  let id: String
  let name: String
  let deadline: Date
  let claimUntil: Date?

  init?(_ data: [String: Any]) {
    guard let id = data["requestId"] as? String,
          let name = data["mealName"] as? String,
          let deadline = Self.date(data["deadlineMs"]) else { return nil }
    self.id = id
    self.name = name
    self.deadline = deadline
    claimUntil = Self.date(data["claimUntilMs"])
  }

  static func date(_ value: Any?) -> Date? {
    (value as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
  }
}

struct RequestList: View {
  @ObservedObject var delegate: WatchNotificationDelegate
  @EnvironmentObject private var connection: PhoneConnection
  @Environment(\.scenePhase) private var scenePhase
  @State private var requests: [MealRequest] = []
  @State private var loaded = false
  @State private var failure: WatchError?
  @State private var loading = false
  @State private var focusedRequest: MealRequest?

  var body: some View {
    List {
      if let failure {
        Text(failure.listMessage)
        Button("Try again") { Task { await refresh() } }
          .disabled(loading)
      } else if !loaded {
        ProgressView()
      } else if requests.isEmpty {
        Text("No pending requests")
      } else {
        ForEach(requests) { request in
          NavigationLink(value: request) {
            VStack(alignment: .leading) {
              Text(request.name)
              let now = Date()
              if request.deadline > now {
                Text(timerInterval: now...request.deadline, countsDown: true)
                  .font(.caption.monospacedDigit())
              }
            }
          }
        }
      }
    }
    .navigationTitle("Meal requests")
    .navigationDestination(for: MealRequest.self) { RequestDetail(request: $0) }
    .navigationDestination(item: $focusedRequest) { RequestDetail(request: $0) }
    .onChange(of: delegate.selectedRequestId, initial: true) { _, _ in
      openSelectedRequest()
    }
    .task(id: scenePhase) {
      guard scenePhase == .active else { return }
      while !Task.isCancelled {
        await refresh()
        try? await Task.sleep(for: .seconds(loaded ? 15 : 3))
      }
    }
  }

  @MainActor
  private func refresh() async {
    guard !loading else { return }
    loading = true
    defer { loading = false }
    do {
      let reply = try await connection.exchange("list")
      guard !Task.isCancelled else { return }
      guard reply["inboxAvailable"] as? Bool == true else { throw WatchError.unavailable }
      requests = (reply["requests"] as? [[String: Any]] ?? [])
        .compactMap(MealRequest.init).filter { $0.deadline > Date() }
      loaded = true
      failure = nil
      openSelectedRequest()
    } catch {
      if !Task.isCancelled { failure = error as? WatchError ?? .unavailable }
    }
  }

  private func openSelectedRequest() {
    guard let id = delegate.selectedRequestId,
          let request = requests.first(where: { $0.id == id }) else { return }
    focusedRequest = request
    delegate.selectedRequestId = nil
  }
}

struct DecisionOption: Identifiable {
  let id: String
  let name: String
  let minutes: Int?

  init?(_ data: [String: Any]) {
    guard let type = data["type"] as? String, let label = data["label"] as? String else { return nil }
    id = type
    name = label
    minutes = data["defaultMinutes"] as? Int
  }
}

struct RequestDetail: View {
  let request: MealRequest
  @EnvironmentObject private var connection: PhoneConnection
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @State private var claimed = false
  @State private var claimUntil: Date?
  @State private var preview: [String: Any] = [:]
  @State private var contextPage = 0
  @State private var choosingDecision = false
  @State private var selected: DecisionOption?
  @State private var minutes = 15
  @State private var busy = false
  @State private var sent = false
  @State private var failureMessage: LocalizedStringKey?
  @State private var now = Date()
  @State private var needsVerification = false
  @State private var renewing = false

  private var hasLiveClaim: Bool {
    guard claimed, let claimUntil else { return false }
    return now < min(claimUntil, request.deadline)
  }

  var body: some View {
    GeometryReader { geometry in
      let scale = min(geometry.size.width, geometry.size.height)
      Group {
        if hasLiveClaim && !sent && !needsVerification && !choosingDecision {
          MealContext(preview: preview, request: request, now: now, page: $contextPage) {
            Task { await changeStage(toDecision: true) }
          }
          .disabled(busy || renewing || scenePhase != .active)
        } else {
          decisionContent(scale: scale)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(mealRequestBackground(scale: scale))
    }
    .navigationTitle("Meal request")
    .task {
      while !Task.isCancelled {
        updateClock()
        try? await Task.sleep(for: .seconds(1))
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active && claimed && !sent { invalidatePreview() }
    }
    .task(id: scenePhase) {
      guard scenePhase == .active else { return }
      updateClock()
      if !sent, let until = claimUntil ?? request.claimUntil, until > now {
        await perform("open")
      }
      var renewAt = Date()
      while !Task.isCancelled {
        if hasLiveClaim, !sent, !busy, !needsVerification, Date() >= renewAt {
          await renewClaim()
          renewAt = Date().addingTimeInterval(8)
        }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private func decisionContent(scale: CGFloat) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: scale * 0.05) {
        if sent {
          Text("Decision sent").font(.headline)
          Button("Close") { dismiss() }
        } else {
          Text(request.name).font(.system(size: scale * 0.12, weight: .bold))
          let deadline = min(claimUntil ?? request.deadline, request.deadline)
          if deadline > now {
            Text(timerInterval: now...deadline, countsDown: true)
              .font(.system(size: scale * 0.095, design: .monospaced))
          }
          if let failureMessage {
            Text(failureMessage).foregroundStyle(.orange)
          }
          if busy { ProgressView() }
          if now >= request.deadline {
            Text("This request has expired.")
            Button("Close") { dismiss() }
          } else if needsVerification && hasLiveClaim {
            Button("Reload meal details") { Task { await perform("open") } }
          } else if hasLiveClaim, let option = selected {
            Text(option.name).font(.system(size: scale * 0.115, weight: .bold))
            if option.minutes != nil {
              Stepper(value: $minutes, in: 1...180) {
                Text("\(minutes) min")
              }
            }
            Button("Send") {
              Task {
                var fields: [String: Any] = ["type": option.id, "message": ""]
                if option.minutes != nil { fields["minutes"] = minutes }
                await perform("respond", fields: fields)
              }
            }.tint(mealRequestAccent)
            Button("Change") { selected = nil }
          } else if hasLiveClaim {
            Button("Meal context") { Task { await changeStage(toDecision: false) } }
            if options.isEmpty {
              Button("Reload meal details") { Task { await perform("open") } }
            } else {
              Text("Choose a decision").font(.system(size: scale * 0.11, weight: .bold))
              ForEach(options) { option in
                Button(option.name) {
                  minutes = option.minutes ?? 15
                  selected = option
                }
              }
            }
          } else {
            Button("Take request") { Task { await perform("claim") } }.tint(mealRequestAccent)
            Button("Decline") { Task { await perform("decline") } }
          }
        }
      }
      .disabled(busy || renewing || scenePhase != .active)
      .padding(.horizontal, scale * 0.035)
      .font(.system(size: scale * 0.085))
    }
  }

  @MainActor
  private func changeStage(toDecision: Bool) async {
    guard hasLiveClaim, !needsVerification, !busy, !renewing,
          scenePhase == .active else { return }
    choosingDecision = toDecision
    await renewClaim()
  }

  private var options: [DecisionOption] {
    (preview["options"] as? [[String: Any]] ?? []).compactMap(DecisionOption.init)
  }

  @MainActor
  private func updateClock() {
    now = Date()
    if claimed && !hasLiveClaim && !busy && !renewing && !sent {
      invalidatePreview()
      claimed = false
      claimUntil = nil
      needsVerification = false
      if now < request.deadline {
        failureMessage = "Your claim expired. Take the request again."
      }
    }
  }

  @MainActor
  private func invalidatePreview() {
    choosingDecision = false
    contextPage = 0
    selected = nil
    preview = [:]
    needsVerification = true
  }

  @MainActor
  private func renewClaim() async {
    renewing = true
    defer { renewing = false }
    let stage = choosingDecision ? "decision" : "context"
    do {
      let reply = try await connection.exchange("presence", request: request.id,
                                                fields: ["stage": stage])
      guard !Task.isCancelled, scenePhase == .active else { return }
      guard let until = MealRequest.date(reply["claimUntilMs"]), until > Date() else {
        throw WatchError.expired
      }
      claimUntil = until
    } catch {
      guard !Task.isCancelled, scenePhase == .active else { return }
      invalidatePreview()
      failureMessage = "Could not confirm your claim. Reload the request to continue."
    }
  }

  @MainActor
  private func perform(_ action: String, fields: [String: Any] = [:]) async {
    updateClock()
    guard !busy, !renewing, !sent, scenePhase == .active, now < request.deadline else { return }
    if action == "respond" {
      guard hasLiveClaim, !needsVerification, selected != nil else { return }
    }
    busy = true
    failureMessage = nil
    defer { busy = false }
    do {
      let reply = try await connection.exchange(action, request: request.id, fields: fields)
      switch action {
      case "respond": sent = true
      case "decline": dismiss()
      default:
        let requests = reply["requests"] as? [[String: Any]]
        guard let until = requests?.first.flatMap({ MealRequest.date($0["claimUntilMs"]) }),
              until > Date(), request.deadline > Date() else {
          throw WatchError.expired
        }
        claimed = true
        claimUntil = until
        guard scenePhase == .active, !Task.isCancelled else {
          invalidatePreview()
          return
        }
        preview = reply["preview"] as? [String: Any] ?? [:]
        needsVerification = false
      }
    } catch WatchError.expired {
      invalidatePreview()
      claimed = false
      claimUntil = nil
      needsVerification = false
      failureMessage = Date() < request.deadline
        ? "Your claim expired. Take the request again."
        : "This request has expired."
    } catch {
      if claimed { invalidatePreview() }
      failureMessage = action == "respond"
        ? "Sending was not confirmed. Check the request on your iPhone."
        : "Open Diabeatthis on your iPhone and try again."
    }
  }
}

private let mealRequestAccent = Color(red: 0.78, green: 0.92, blue: 0.59)
private let mealRequestSurface = Color(red: 0.14, green: 0.21, blue: 0.17)

private func mealRequestBackground(scale: CGFloat) -> RadialGradient {
  RadialGradient(colors: [mealRequestSurface, Color(red: 0.06, green: 0.10, blue: 0.08)],
                 center: .top, startRadius: 0, endRadius: scale)
}

struct MealContext: View {
  let preview: [String: Any]
  let request: MealRequest
  let now: Date
  @Binding var page: Int
  let chooseDecision: () -> Void

  private let accent = mealRequestAccent
  private let surface = mealRequestSurface
  private let muted = Color(red: 0.71, green: 0.78, blue: 0.73)
  private let lastPage = 5

  var body: some View {
    GeometryReader { geometry in
      let scale = min(geometry.size.width, geometry.size.height)
      VStack(spacing: scale * 0.025) {
        VStack(spacing: scale * 0.03) {
          pageContent(scale: scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.72)

        HStack {
          Button {
            if page > 0 { page -= 1 }
          } label: {
            Image(systemName: "chevron.left")
          }
          .accessibilityLabel("Previous page")
          .disabled(page == 0)
          Spacer(minLength: scale * 0.04)
          Button(action: advance) {
            HStack(spacing: scale * 0.025) {
              Text(page == lastPage
                ? LocalizedStringKey("Choose a decision")
                : LocalizedStringKey("Next page"))
              Image(systemName: "chevron.right")
            }
          }
        }
        .buttonStyle(.plain)
        .font(.system(size: scale * 0.077, weight: .semibold))
        .foregroundStyle(accent)
        .padding(.vertical, scale * 0.02)

        HStack(spacing: scale * 0.025) {
          ForEach(0...lastPage, id: \.self) { index in
            Capsule().fill(index == page ? accent : muted.opacity(0.32))
          }
        }
        .frame(width: geometry.size.width * 0.58, height: scale * 0.02)
        .accessibilityHidden(true)
      }
      .padding(.horizontal, geometry.size.width * 0.08)
      .padding(.vertical, geometry.size.height * 0.045)
      .frame(width: geometry.size.width, height: geometry.size.height)
      .contentShape(Rectangle())
      .gesture(DragGesture(minimumDistance: scale * 0.15).onEnded { gesture in
        guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
        if gesture.translation.width < 0 {
          advance()
        } else if page > 0 {
          page -= 1
        }
      })
    }
  }

  private func advance() {
    if page == lastPage { chooseDecision() }
    else { page += 1 }
  }

  @ViewBuilder
  private func pageContent(scale: CGFloat) -> some View {
    switch page {
    case 0:
      let parts = request.name.split(separator: ":", maxSplits: 1)
      let title = parts.count == 2 && parts[0] != "QM" ? String(parts[0]) : request.name
      Text(title).font(.system(size: scale * 0.15, weight: .bold)).lineLimit(2)
      if request.deadline > now {
        Text(timerInterval: now...request.deadline, countsDown: true)
          .font(.system(size: scale * 0.13, weight: .semibold, design: .monospaced))
          .foregroundStyle(accent)
      }
      glucose(scale: scale, large: true)
    case 1:
      heading("Planned meal", scale: scale)
      if let planned = MealRequest.date(preview["plannedAtMs"]) {
        Text(planned, style: .time).foregroundStyle(muted)
          .font(.system(size: scale * 0.10, weight: .semibold))
      }
      HStack(spacing: scale * 0.05) {
        macro("Carbs", key: "mealCarbs", scale: scale)
        macro("eCarbs", key: "mealExtendedCarbs", scale: scale)
      }
      if let carbs = preview["mealCarbs"] as? Int,
         let extended = preview["mealExtendedCarbs"] as? Int,
         carbs >= 0, extended >= 0, Double(carbs) + Double(extended) > 0 {
        let share = CGFloat(Double(carbs) / (Double(carbs) + Double(extended)))
        GeometryReader { bar in
          HStack(spacing: 0) {
            Color.cyan.frame(width: bar.size.width * share)
            Color.orange
          }
          .clipShape(Capsule())
        }
        .frame(height: scale * 0.03)
        .accessibilityHidden(true)
      }
    case 2:
      heading("Glucose", scale: scale)
      glucose(scale: scale, large: false)
      series("glucoseHistory", color: .orange, scale: scale)
    case 3:
      heading("IOB", scale: scale)
      activeValue("iob", unit: "U", scale: scale)
      series("iobHistory", color: .cyan, scale: scale)
    case 4:
      heading("COB", scale: scale)
      activeValue("cob", unit: "g", scale: scale)
      series("cobHistory", color: accent, scale: scale)
    default:
      heading("Meal advisor suggestion", scale: scale)
      advisorSuggestion(scale: scale)
    }
  }

  private func heading(_ title: LocalizedStringKey, scale: CGFloat) -> some View {
    Text(title).font(.system(size: scale * 0.125, weight: .bold)).lineLimit(2)
  }

  @ViewBuilder
  private func glucose(scale: CGFloat, large: Bool) -> some View {
    if let value = preview["glucoseMgDl"] as? Int,
       let time = MealRequest.date(preview["glucoseAtMs"]) {
      HStack(spacing: scale * 0.035) {
        Text("\(value)").font(.system(size: scale * (large ? 0.24 : 0.14), weight: .bold))
        Text("mg/dL").font(.system(size: scale * 0.075)).foregroundStyle(muted)
        if let direction = preview["glucoseDirection"] as? String,
           let arrow = Self.trendArrows[direction] {
          Text(arrow).font(.system(size: scale * 0.14, weight: .semibold)).foregroundStyle(accent)
        }
      }
      HStack(spacing: scale * 0.03) {
        Text(time, style: .time).foregroundStyle(muted)
        if let delta = glucoseChange(value: value, time: time) {
          Text(delta, format: .number.sign(strategy: .always()))
            .foregroundStyle(accent)
        }
      }
      .font(.system(size: scale * 0.074))
      if now.timeIntervalSince(time) > 300 {
        Text("Glucose reading is over 5 min old.")
          .font(.system(size: scale * 0.074, weight: .semibold)).foregroundStyle(.orange).lineLimit(2)
      }
    } else {
      Text("Glucose reading unavailable.")
        .font(.system(size: scale * 0.08)).foregroundStyle(.orange).lineLimit(2)
    }
  }

  private static let trendArrows = [
    "DoubleUp": "↑↑", "SingleUp": "↑", "FortyFiveUp": "↗", "Flat": "→",
    "FortyFiveDown": "↘", "SingleDown": "↓", "DoubleDown": "↓↓",
  ]

  private func glucoseChange(value: Int, time: Date) -> Int? {
    let timestamp = time.timeIntervalSince1970 * 1000
    let previous = (preview["glucoseHistory"] as? [[Double]] ?? [])
      .filter { $0.count == 2 && $0[0] < timestamp.rounded()
        && timestamp - $0[0] <= 600_000 && $0[1].isFinite }
      .max { $0[0] < $1[0] }
    return previous.flatMap { Int(exactly: (Double(value) - $0[1]).rounded(.towardZero)) }
  }

  private func macro(_ title: LocalizedStringKey, key: String, scale: CGFloat) -> some View {
    VStack(spacing: scale * 0.025) {
      Text(title).font(.system(size: scale * 0.075)).foregroundStyle(muted)
      if let grams = preview[key] as? Int {
        Text("\(grams) g").font(.system(size: scale * 0.12, weight: .bold))
      } else {
        Text("—").font(.system(size: scale * 0.12))
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, scale * 0.06)
    .background(surface, in: RoundedRectangle(cornerRadius: scale * 0.07))
  }

  @ViewBuilder
  private func advisorSuggestion(scale: CGFloat) -> some View {
    if let suggestion = preview["advisorSuggestion"] as? [String: Any],
       let type = suggestion["type"] as? String,
       let option = (preview["options"] as? [[String: Any]] ?? [])
         .compactMap(DecisionOption.init).first(where: { $0.id == type }) {
      Text("From the child's phone")
        .font(.system(size: scale * 0.077)).foregroundStyle(muted)
      VStack(spacing: scale * 0.025) {
        Text(option.name).font(.system(size: scale * 0.09, weight: .semibold)).lineLimit(3)
        if let minutes = suggestion["minutes"] as? Int {
          Text("\(minutes) min")
            .font(.system(size: scale * 0.16, weight: .bold)).foregroundStyle(accent)
          Text("Then eat").font(.system(size: scale * 0.072)).foregroundStyle(muted)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(scale * 0.045)
      .background(surface, in: RoundedRectangle(cornerRadius: scale * 0.075))
    } else {
      Text("Meal advisor suggestion unavailable.")
        .font(.system(size: scale * 0.08)).foregroundStyle(muted).lineLimit(2)
    }
  }

  @ViewBuilder
  private func activeValue(_ key: String, unit: String, scale: CGFloat) -> some View {
    if let value = preview[key] as? Double {
      HStack(spacing: scale * 0.025) {
        Text(value, format: .number.precision(.fractionLength(0...2)))
          .font(.system(size: scale * 0.16, weight: .bold))
        Text(unit).font(.system(size: scale * 0.075)).foregroundStyle(muted)
      }
    }
  }

  @ViewBuilder
  private func series(_ key: String, color: Color, scale: CGFloat) -> some View {
    let points = (preview[key] as? [[Double]] ?? []).filter { $0.count == 2 }
    if points.count > 1 {
      Chart(points.indices, id: \.self) { index in
        let point = points[index]
        LineMark(x: .value("Time", Date(timeIntervalSince1970: point[0] / 1000)),
                 y: .value("Value", point[1]))
          .foregroundStyle(color)
          .interpolationMethod(key == "glucoseHistory" ? .linear : .stepEnd)
      }
      .chartXAxis(.hidden)
      .chartYAxis {
        AxisMarks(values: .automatic(desiredCount: 3)) { axis in
          AxisGridLine()
          AxisValueLabel {
            if let value = axis.as(Double.self) {
              Text(value, format: .number.precision(.fractionLength(0...1)))
                .font(.system(size: scale * 0.055))
            }
          }
        }
      }
      .frame(height: scale * 0.30)
    } else {
      Text("Glucose and treatment history unavailable.")
        .font(.system(size: scale * 0.075)).foregroundStyle(muted).lineLimit(2)
    }
  }
}
