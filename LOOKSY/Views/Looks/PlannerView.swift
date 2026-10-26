import SwiftUI
import SwiftData

/// Local weekly planner (does not use Apple Calendar).
struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannedOutfit.day) private var plans: [PlannedOutfit]
    @Query private var looks: [Look]
    @State private var weekOffset = 0
    @State private var pickingDay: PlannerDay?

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "es_MX")
        return calendar
    }

    private var days: [Date] {
        WeekPlanner.days(of: Date(), weekOffset: weekOffset, calendar: calendar)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        weekOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Semana anterior")
                    Spacer()
                    VStack {
                        Text(weekTitle).font(.headline)
                        if weekOffset != 0 {
                            Button("Ir a esta semana") { weekOffset = 0 }
                                .font(.caption)
                        }
                    }
                    Spacer()
                    Button {
                        weekOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Semana siguiente")
                }
                .buttonStyle(.borderless)
            }

            ForEach(days, id: \.self) { day in
                Section {
                    let dayPlans = plans.filter { calendar.isDate($0.day, inSameDayAs: day) }
                    ForEach(dayPlans) { plan in
                        planRow(plan)
                    }
                    Button {
                        pickingDay = PlannerDay(date: day)
                    } label: {
                        Label(dayPlans.isEmpty ? "Planificar look" : "Añadir otro look", systemImage: "plus")
                            .font(.subheadline)
                    }
                } header: {
                    HStack {
                        Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "es_MX"))).capitalized)
                        if calendar.isDateInToday(day) {
                            Text("HOY")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent, in: Capsule())
                                .foregroundStyle(Theme.onAccent)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(item: $pickingDay) { day in
            LookPickerSheet(title: day.date.formatted(date: .abbreviated, time: .omitted)) { look in
                context.insert(PlannedOutfit(day: day.date, lookID: look.id))
                try? context.save()
            }
        }
    }

    private var weekTitle: String {
        guard let first = days.first, let last = days.last else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    @ViewBuilder
    private func planRow(_ plan: PlannedOutfit) -> some View {
        if let look = looks.first(where: { $0.id == plan.lookID }) {
            NavigationLink(value: look) {
                HStack(spacing: 12) {
                    StoredImageView(fileName: look.exportedImageFileName, contentMode: .fit, placeholderSymbol: "square.grid.2x2")
                        .frame(width: 48, height: 60)
                        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading) {
                        Text(look.name).foregroundStyle(Theme.text)
                        if plan.markedAsWorn {
                            Label("Usado", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    context.delete(plan)
                    try? context.save()
                } label: {
                    Label("Quitar", systemImage: "calendar.badge.minus")
                }
            }
            .swipeActions(edge: .leading) {
                if !plan.markedAsWorn {
                    Button {
                        plan.markedAsWorn = true
                        look.lastWornAt = plan.day
                        WardrobeService(context: context).markWorn(look.garmentIDs, on: plan.day)
                        try? context.save()
                    } label: {
                        Label("Usado", systemImage: "checkmark.seal")
                    }
                    .tint(Theme.accent)
                }
            }
        } else {
            HStack {
                Label("Look eliminado", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Quitar") {
                    context.delete(plan)
                    try? context.save()
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct PlannerDay: Identifiable {
    var date: Date
    var id: Date { date }
}

enum WeekPlanner {
    /// The seven days (Monday first in es_MX) of the week containing `date`, shifted by `weekOffset`.
    static func days(of date: Date, weekOffset: Int, calendar: Calendar) -> [Date] {
        var calendar = calendar
        calendar.firstWeekday = 2
        guard let shifted = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: date),
              let interval = calendar.dateInterval(of: .weekOfYear, for: shifted) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }
}
