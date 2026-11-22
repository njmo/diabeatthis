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
      throw WatchError.unavailable
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
        default: continuation.resume(throwing: WatchError.unavailable)
        }
      }, errorHandler: { _ in
        continuation.resume(throwing: WatchError.unavailable)
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
  @State private var failed = false
  @State private var focusedRequest: MealRequest?

  var body: some View {
    List {
      if failed {
        Text("Open Diabeatthis on your iPhone and try again.")
        Button("Try again") { Task { await refresh() } }
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
        try? await Task.sleep(for: .seconds(15))
      }
    }
  }

  @MainActor
  private func refresh() async {
    do {
      let reply = try await connection.exchange("list")
      guard !Task.isCancelled else { return }
      guard reply["inboxAvailable"] as? Bool == true else { throw WatchError.unavailable }
      requests = (reply["requests"] as? [[String: Any]] ?? [])
        .compactMap(MealRequest.init).filter { $0.deadline > Date() }
      loaded = true
      failed = false
      openSelectedRequest()
    } catch {
      if !Task.isCancelled { failed = true }
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
  @State private var error: LocalizedStringKey?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if sent {
          Text("Decision sent").font(.headline)
          Button("Close") { dismiss() }
        } else {
          Text(request.name).font(.headline)
          let deadline = min(claimUntil ?? request.deadline, request.deadline)
          let now = Date()
          if deadline > now {
            Text(timerInterval: now...deadline, countsDown: true)
              .font(.caption.monospacedDigit())
          }
          if let error { Text(error).font(.footnote).foregroundStyle(.orange) }
          if busy { ProgressView() }
          if let selected {
            Text(selected.name).font(.headline)
            if selected.minutes != nil {
              Stepper(value: $minutes, in: 1...180) {
                Text("\(minutes) min")
              }
            }
            Button("Send") {
              Task {
                var fields: [String: Any] = ["type": selected.id, "message": ""]
                if selected.minutes != nil { fields["minutes"] = minutes }
                await perform("respond", fields: fields)
              }
            }.tint(.green)
            Button("Change") { selected = nil }
          } else if claimed {
            MealContext(preview: preview)
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
      .disabled(busy)
      .padding(.horizontal, 4)
    }
    .navigationTitle("Meal request")
    .task {
      if let until = request.claimUntil, until > Date() { await perform("open") }
    }
    .task(id: claimed && !sent && scenePhase == .active) {
      guard claimed, !sent, scenePhase == .active else { return }
      while !Task.isCancelled {
        if !busy {
          let stage = selected == nil ? "context" : "decision"
          if let reply = try? await connection.exchange("presence", request: request.id,
                                                       fields: ["stage": stage]),
             !Task.isCancelled {
            claimUntil = MealRequest.date(reply["claimUntilMs"])
          }
        }
        try? await Task.sleep(for: .seconds(8))
      }
    }
  }

  private var options: [DecisionOption] {
    (preview["options"] as? [[String: Any]] ?? []).compactMap(DecisionOption.init)
  }

  @MainActor
  private func perform(_ action: String, fields: [String: Any] = [:]) async {
    guard !busy else { return }
    busy = true
    error = nil
    defer { busy = false }
    do {
      let reply = try await connection.exchange(action, request: request.id, fields: fields)
      switch action {
      case "respond": sent = true
      case "decline": dismiss()
      default:
        claimed = true
        preview = reply["preview"] as? [String: Any] ?? [:]
        let requests = reply["requests"] as? [[String: Any]]
        claimUntil = requests?.first.flatMap { MealRequest.date($0["claimUntilMs"]) }
      }
    } catch WatchError.expired {
      error = "This request has expired."
    } catch {
      error = action == "respond"
        ? "Sending was not confirmed. Check the request on your iPhone."
        : "Open Diabeatthis on your iPhone and try again."
    }
  }
}

struct MealContext: View {
  let preview: [String: Any]

  var body: some View {
    if let glucose = preview["glucoseMgDl"] as? Int,
       let time = MealRequest.date(preview["glucoseAtMs"]) {
      Text("\(glucose) mg/dL").font(.title3.bold())
      Text(time, style: .time).font(.caption)
    }
    if let carbs = preview["mealCarbs"] as? Int,
       let extended = preview["mealExtendedCarbs"] as? Int {
      Text("Carbs \(carbs) g · eCarbs \(extended) g").font(.caption)
    }
    series("Glucose", key: "glucoseHistory", color: .orange)
    series("IOB", key: "iobHistory", color: .cyan)
    series("COB", key: "cobHistory", color: .green)
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
