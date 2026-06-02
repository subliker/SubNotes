import Foundation
import Testing
@testable import CalendarCore

@Suite struct ReminderSchedulerTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// An event whose start is `startsInMinutes` from `now`, with alarms at the
    /// given minute offsets relative to `now` (negative = past).
    private func event(
        _ id: String,
        startsInMinutes: Double = 60,
        durationMinutes: Double = 30,
        remindersAtMinutes minutes: [Double]
    ) -> CalEvent {
        let start = now.addingTimeInterval(startsInMinutes * 60)
        return CalEvent(
            id: id,
            title: id,
            start: start,
            end: start.addingTimeInterval(durationMinutes * 60),
            reminders: minutes.map { now.addingTimeInterval($0 * 60) }
        )
    }

    // MARK: - triggers

    @Test func triggersExpandsEachAlarmIntoOwnTrigger() {
        let e = event("e", startsInMinutes: 60, remindersAtMinutes: [10, 30])
        let triggers = ReminderScheduler.triggers([e], now: now)
        #expect(triggers.count == 2)
        #expect(triggers.map(\.fireDate) == [10, 30].map { now.addingTimeInterval($0 * 60) })
    }

    @Test func triggersSortedSoonestFirstAcrossEvents() {
        let a = event("a", startsInMinutes: 90, remindersAtMinutes: [40])
        let b = event("b", startsInMinutes: 30, remindersAtMinutes: [5])
        let triggers = ReminderScheduler.triggers([a, b], now: now)
        #expect(triggers.map(\.event.id) == ["b", "a"])
    }

    @Test func triggersDropRemindersForEndedEvents() {
        // Event already finished an hour ago, alarm fired even earlier.
        let stale = event("stale", startsInMinutes: -120, durationMinutes: 30,
                          remindersAtMinutes: [-130])
        let live = event("live", startsInMinutes: 60, remindersAtMinutes: [45])
        let triggers = ReminderScheduler.triggers([stale, live], now: now)
        #expect(triggers.map(\.event.id) == ["live"])
    }

    @Test func eventWithoutAlarmsYieldsNoTriggers() {
        let e = event("e", remindersAtMinutes: [])
        #expect(ReminderScheduler.triggers([e], now: now).isEmpty)
    }

    // MARK: - nextFireDate

    @Test func nextFireDateIsEarliestFutureTrigger() {
        let a = event("a", startsInMinutes: 90, remindersAtMinutes: [20, 60])
        let b = event("b", startsInMinutes: 30, remindersAtMinutes: [-5, 10])
        let next = ReminderScheduler.nextFireDate([a, b], after: now)
        #expect(next == now.addingTimeInterval(10 * 60))
    }

    @Test func nextFireDateIgnoresDueTriggers() {
        // Only a past-due alarm: nothing strictly in the future → nil.
        let e = event("e", startsInMinutes: 60, remindersAtMinutes: [-5])
        #expect(ReminderScheduler.nextFireDate([e], after: now) == nil)
    }

    @Test func nextFireDateNilWhenNoReminders() {
        #expect(ReminderScheduler.nextFireDate([], after: now) == nil)
    }

    // MARK: - due / queue

    @Test func dueReturnsOnlyFiredReminders() {
        let e = event("e", startsInMinutes: 60, remindersAtMinutes: [-5, 30])
        let due = ReminderScheduler.due([e], now: now)
        #expect(due.count == 1)
        #expect(due.first?.fireDate == now.addingTimeInterval(-5 * 60))
    }

    @Test func dueIncludesReminderFiredExactlyNow() {
        let e = event("e", startsInMinutes: 60, remindersAtMinutes: [0])
        #expect(ReminderScheduler.due([e], now: now).count == 1)
    }

    @Test func dueQueuesSimultaneousRemindersByEventStart() {
        // Two reminders fire at the same instant (5 min ago); the one whose
        // event starts sooner should present first.
        let later = event("later", startsInMinutes: 90, remindersAtMinutes: [-5])
        let sooner = event("sooner", startsInMinutes: 20, remindersAtMinutes: [-5])
        let due = ReminderScheduler.due([later, sooner], now: now)
        #expect(due.map(\.event.id) == ["sooner", "later"])
    }

    @Test func dueCoalescesNearSimultaneousFires() {
        // Fires 0.5s apart: within the default 1s window, ordered by event start
        // (sooner first) rather than by raw fire instant (which would be later2).
        let start = now.addingTimeInterval(-10 * 60)
        let later2 = CalEvent(id: "later2", title: "later2", start: now.addingTimeInterval(80 * 60),
                              end: now.addingTimeInterval(110 * 60),
                              reminders: [start])
        let sooner = CalEvent(id: "sooner", title: "sooner", start: now.addingTimeInterval(15 * 60),
                              end: now.addingTimeInterval(45 * 60),
                              reminders: [start.addingTimeInterval(0.5)])
        let due = ReminderScheduler.due([later2, sooner], now: now)
        #expect(due.map(\.event.id) == ["sooner", "later2"])
    }

    @Test func dueKeepsDistinctGroupsInFireOrder() {
        // Two reminders 10s apart exceed the 1s coalesce window: stay in fire
        // order regardless of event start.
        let firstFire = now.addingTimeInterval(-60)
        let secondFire = now.addingTimeInterval(-50)
        let laterStart = CalEvent(id: "laterStart", title: "laterStart",
                                  start: now.addingTimeInterval(5 * 60),
                                  end: now.addingTimeInterval(35 * 60),
                                  reminders: [firstFire])
        let soonerStart = CalEvent(id: "soonerStart", title: "soonerStart",
                                   start: now.addingTimeInterval(2 * 60),
                                   end: now.addingTimeInterval(32 * 60),
                                   reminders: [secondFire])
        let due = ReminderScheduler.due([laterStart, soonerStart], now: now)
        #expect(due.map(\.event.id) == ["laterStart", "soonerStart"])
    }

    // MARK: - identity

    @Test func triggerIdIsStablePerEventAndFireDate() {
        let e = event("e", startsInMinutes: 60, remindersAtMinutes: [10])
        let t1 = ReminderScheduler.triggers([e], now: now).first
        let t2 = ReminderScheduler.triggers([e], now: now).first
        #expect(t1?.id == t2?.id)
    }
}
