import FirebaseFirestore

struct League {
    var id: String
    var name: String
    var hostUserId: String
    var members: [String]
    var course: String
    var schedule: String
    var createdAt: Timestamp

    // Initialize the model
    init(id: String = "", name: String, hostUserId: String, members: [String], course: String, schedule: String, createdAt: Timestamp = Timestamp(date: Date())) {
        self.id = id
        self.name = name
        self.hostUserId = hostUserId
        self.members = members
        self.course = course
        self.schedule = schedule
        self.createdAt = createdAt
    }

    // Convert model to Firestore dictionary
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "hostUserId": hostUserId,
            "members": members,
            "course": course,
            "schedule": schedule,
            "createdAt": createdAt
        ]
    }

    // Define Round model here
    struct Round {
        var id: String // Add this ID
        var number: Int
        var score: Int
        var createdAt: Timestamp
    }

    // Define Score model here
    struct Score {
        var id: UUID
        var userId: String
        var holeScores: [Int]
    }
}
