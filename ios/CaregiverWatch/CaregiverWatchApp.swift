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
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if sent {
          Text("Decision sent").font(.headline)
          Button("Close") { dismiss() }
        } else {
          Text(request.name).font(.headline)
          let deadline = min(claimUntil ?? request.deadline, request.deadline)
          if deadline > now {
            Text(timerInterval: now...deadline, countsDown: true)
              .font(.caption.monospacedDigit())
          }
          if let failureMessage {
            Text(failureMessage).font(.footnote).foregroundStyle(.orange)
          }
          if busy { ProgressView() }
          if now >= request.deadline {
            Text("This request has expired.").font(.footnote)
            Button("Close") { dismiss() }
          } else if needsVerification && hasLiveClaim {
            Button("Reload meal details") { Task { await perform("open") } }
          } else if hasLiveClaim, let option = selected {
            Text(option.name).font(.headline)
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
            }.tint(.green)
            Button("Change") { selected = nil }
          } else if hasLiveClaim {
            MealContext(preview: preview, now: now)
            if options.isEmpty {
              Button("Reload meal details") { Task { await perform("open") } }
            } else {
              Text("Choose a decision").font(.headline)
              ForEach(options) { option in
                Button(option.name) {
                  minutes = option.minutes ?? 15
                  selected = option
                }
              }
            }
          } else {
            Button("Take request") { Task { await perform("claim") } }.tint(.green)
            Button("Decline") { Task { await perform("decline") } }
          }
        }
      }
      .disabled(busy || renewing || scenePhase != .active)
      .padding(.horizontal, 4)
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
    selected = nil
    preview = [:]
    needsVerification = true
  }

  @MainActor
  private func renewClaim() async {
    renewing = true
    defer { renewing = false }
    let stage = selected == nil ? "context" : "decision"
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

struct MealContext: View {
  let preview: [String: Any]
  let now: Date

  var body: some View {
    if let planned = MealRequest.date(preview["plannedAtMs"]) {
      Text("Planned meal").font(.caption.bold())
      Text(planned, format: .dateTime.day().month().hour().minute()).font(.caption)
    }
    ForEach(Array((preview["ingredients"] as? [[String: Any]] ?? []).enumerated()), id: \.offset) { row in
      if let name = row.element["name"] as? String {
        Text(name).font(.caption)
      }
    }
    glucoseReading
    if preview["historyAvailable"] as? Bool != true {
      Text("Glucose and treatment history unavailable.")
        .font(.caption).foregroundStyle(.orange)
    } else if let synced = MealRequest.date(preview["historySyncedAtMs"]) {
      HStack {
        Text("History synced")
        Text(synced, style: .time)
      }.font(.caption2)
    }
    if let carbs = preview["mealCarbs"] as? Int,
       let extended = preview["mealExtendedCarbs"] as? Int {
      Text("Carbs \(carbs) g · eCarbs \(extended) g").font(.caption)
    }
    series("Glucose", key: "glucoseHistory", color: .orange)
    activeValue("IOB", key: "iob", unit: "U")
    series("IOB", key: "iobHistory", color: .cyan)
    activeValue("COB", key: "cob", unit: "g")
    series("COB", key: "cobHistory", color: .green)
    if let notices = preview["notices"] as? [String], !notices.isEmpty {
      Text("Meal context").font(.caption.bold())
      ForEach(Array(notices.enumerated()), id: \.offset) { notice in
        Text(notice.element).font(.caption)
      }
    }
    advisorSuggestion
  }

  @ViewBuilder
  private var glucoseReading: some View {
    if let glucose = preview["glucoseMgDl"] as? Int,
       let time = MealRequest.date(preview["glucoseAtMs"]) {
      HStack {
        Text("\(glucose) mg/dL").font(.title3.bold())
        if let direction = preview["glucoseDirection"] as? String,
           let arrow = Self.trendArrows[direction] {
          Text(arrow).font(.headline).foregroundStyle(.green)
        }
      }
      Text(time, style: .time).font(.caption)
      if now.timeIntervalSince(time) > 300 {
        Text("Glucose reading is over 5 min old.")
          .font(.caption).foregroundStyle(.orange)
      }
    } else {
      Text("Glucose reading unavailable.").font(.caption).foregroundStyle(.orange)
    }
  }

  private static let trendArrows = [
    "DoubleUp": "↑↑", "SingleUp": "↑", "FortyFiveUp": "↗", "Flat": "→",
    "FortyFiveDown": "↘", "SingleDown": "↓", "DoubleDown": "↓↓",
  ]

  @ViewBuilder
  private var advisorSuggestion: some View {
    if let suggestion = preview["advisorSuggestion"] as? [String: Any],
       let type = suggestion["type"] as? String,
       let option = (preview["options"] as? [[String: Any]] ?? [])
         .compactMap(DecisionOption.init).first(where: { $0.id == type }) {
      Text("Meal advisor suggestion").font(.caption.bold())
      Text(option.name)
      if let minutes = suggestion["minutes"] as? Int {
        Text("\(minutes) min")
      }
    }
  }

  @ViewBuilder
  private func activeValue(_ title: LocalizedStringKey, key: String, unit: String) -> some View {
    if let value = preview[key] as? Double {
      HStack {
        Text(title).bold()
        Text(value, format: .number.precision(.fractionLength(0...2)))
        Text(unit)
      }.font(.caption)
      if let time = MealRequest.date(preview["deviceAtMs"]) {
        Text(time, style: .time).font(.caption2)
      }
    }
  }

  @ViewBuilder
  private func series(_ title: LocalizedStringKey, key: String, color: Color) -> some View {
    let points = (preview[key] as? [[Double]] ?? []).filter { $0.count == 2 }
    if points.count > 1 {
      Text(title).font(.caption.bold())
      Chart(points.indices, id: \.self) { index in
        let point = points[index]
        LineMark(x: .value("Time", Date(timeIntervalSince1970: point[0] / 1000)),
                 y: .value("Value", point[1]))
          .foregroundStyle(color)
          .interpolationMethod(key == "glucoseHistory" ? .linear : .stepEnd)
      }
      .chartXAxis(.hidden)
      .frame(height: 56)
    }
  }
}
