import Foundation

struct ChildSpecialist: Identifiable {
    var id: Int
    var name: String
    var specialization: String?

    // UI compatibility — API يرجع اسم عربي فقط حالياً
    var nameEn: String { name }
    var specialty: String { specialization ?? "" }
    var specialtyEn: String { specialization ?? "" }
}

struct ToiletReminderInfo {
    var isActive: Bool
    var intervalMinutes: Int
    var startTime: String
    var endTime: String
}

struct Child: Identifiable {
    var id: Int
    var name: String
    var nurseryOnly: Bool
    var specialists: [ChildSpecialist]
    var arrivalTime: String?    // ISO8601 — وقت الوصول اليوم
    var departureTime: String?  // ISO8601 — وقت المغادرة اليوم
    var toiletReminder: ToiletReminderInfo?

    var isNurseryOnly: Bool { nurseryOnly || specialists.isEmpty }
    var childClass: String { "" }

    var arrivalTimeFormatted: String? {
        guard let iso = arrivalTime else { return nil }
        return formatTime(iso)
    }

    var departureTimeFormatted: String? {
        guard let iso = departureTime else { return nil }
        return formatTime(iso)
    }

    private func formatTime(_ iso: String) -> String? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return nil }
        let df = DateFormatter()
        df.dateFormat = "hh:mm a"
        df.locale = Locale(identifier: "ar")
        return df.string(from: date)
    }
}

struct User: Identifiable {
    var id: Int
    var name: String
    var phone: String
    var carPhotoUrl: String?
    var children: [Child]
    var activeChildId: Int

    var activeChild: Child? {
        children.first { $0.id == activeChildId } ?? children.first
    }

    var childName: String { activeChild?.name ?? "" }
    var childClass: String { activeChild?.childClass ?? "" }
}
