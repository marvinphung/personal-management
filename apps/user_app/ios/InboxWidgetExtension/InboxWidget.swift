import SwiftUI
import WidgetKit

struct WidgetColors {
    static let background = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 11/255, green: 19/255, blue: 19/255, alpha: 1)
            : UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1)
    })
    static let primary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 45/255, green: 212/255, blue: 191/255, alpha: 1)
            : UIColor(red: 15/255, green: 118/255, blue: 110/255, alpha: 1)
    })
    static let textPrimary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1)
            : UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)
    })
    static let textSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1)
            : UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
    })
    static let warning = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1)
            : UIColor(red: 217/255, green: 119/255, blue: 6/255, alpha: 1)
    })
}

extension View {
    @ViewBuilder
    func applyWidgetContainerBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                WidgetColors.background
            }
        } else {
            self.background(WidgetColors.background)
        }
    }
}

public struct InboxWidgetEntryView: View {
    var entry: InboxTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    public init(entry: InboxTimelineProvider.Entry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WidgetColors.primary)
                Text("BIẾN ĐỘNG")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(WidgetColors.textSecondary)
                Spacer()
                if entry.isOffline {
                    Circle()
                        .fill(WidgetColors.warning)
                        .frame(width: 7, height: 7)
                }
            }

            Spacer(minLength: 4)

            // Content
            if !entry.isLoggedIn {
                Text("—")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textSecondary)

                Text("Chưa đăng nhập")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WidgetColors.textSecondary)

                Spacer(minLength: 4)

                Text("Đăng nhập để xem →")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WidgetColors.primary)
            } else if entry.count == 0 {
                Text("0")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)

                Text("Đã xử lý hết")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WidgetColors.textSecondary)

                Spacer(minLength: 4)

                Text("Không có biến động mới")
                    .font(.system(size: 11))
                    .foregroundColor(WidgetColors.textSecondary)
            } else {
                Text("\(entry.count)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                    .minimumScaleFactor(0.8)

                Text("giao dịch cần phân loại")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WidgetColors.textSecondary)
                    .lineLimit(2)

                Spacer(minLength: 4)

                Text("Chạm để duyệt →")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(WidgetColors.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .applyWidgetContainerBackground()
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
