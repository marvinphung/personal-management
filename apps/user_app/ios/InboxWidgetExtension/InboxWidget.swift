import SwiftUI
import WidgetKit

public struct InboxWidgetEntryView: View {
    var entry: InboxTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    public init(entry: InboxTimelineProvider.Entry) {
        self.entry = entry
    }

    public var body: some View {
        ZStack {
            Color("WidgetBackground", bundle: nil)
                .edgesIgnoringSafeArea(.all)

            if !entry.isLoggedIn {
                VStack(spacing: 8) {
                    Image(systemName: "lock.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Chưa đăng nhập")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text("Chạm để mở ứng dụng")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "tray.full")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        Text("Biến động")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        if entry.isOffline {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 7, height: 7)
                        }
                    }

                    Spacer()

                    if entry.count > 0 {
                        Text("\(entry.count)")
                            .font(.system(size: family == .systemSmall ? 38 : 46, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.8)

                        Text("giao dịch cần phân loại")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("0")
                            .font(.system(size: family == .systemSmall ? 38 : 46, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)

                        Text("Không có giao dịch cần phân loại")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .widgetURL(URL(string: "quanlytao://bank-inbox"))
    }
}

@main
public struct InboxWidgetBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        InboxWidget()
    }
}

public struct InboxWidget: Widget {
    let kind: String = "InboxWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InboxTimelineProvider()) { entry in
            InboxWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Biến động ngân hàng")
        .description("Theo dõi số lượng giao dịch biến động ngân hàng đang chờ phân loại.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
