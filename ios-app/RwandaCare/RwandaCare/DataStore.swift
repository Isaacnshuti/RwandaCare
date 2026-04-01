import Foundation
import Supabase
import Combine

// MARK: - Database Models
struct UserProfile: Codable {
    let id: UUID
    let first_name: String
    let last_name: String
    let national_id: String?
    let phone: String?
    let date_of_birth: String?
    let sex: String?
    let address: String?
    let profession: String?
    let weight: String?
    let height: String?
    let blood_type: String?
    let insurance_num: String?
    let is_verified: Bool?
}

struct FacilityDTO: Codable {
    let id: UUID
    let name: String
    let phone: String?
    let address: String?
    let district: String?
    let type: String
    let latitude: Double?
    let longitude: Double?
    let is_open_24h: Bool?
    let rating: Double?
    let services: [String]?
}

struct DoctorDTO: Codable {
    let id: UUID
    let name: String
    let specialty: String?
    let hospital: String?
    let experience: String?
    let consult_fee: String?
    let image_placeholder: String?
    let rating: Double?
    let slots: [String]?
}

struct AppointmentDTO: Codable {
    let id: UUID
    let doctor_name: String
    let specialty: String?
    let hospital: String?
    let appointment_date: String
    let appointment_time: String
    let appointment_id_string: String
    let status: String?
}

struct AppointmentInsertDTO: Codable {
    let patient_id: UUID
    let doctor_name: String
    let specialty: String?
    let hospital: String?
    let appointment_date: String
    let appointment_time: String
    let appointment_id_string: String
    let status: String?
}

struct LabResultDTO: Codable { let id: UUID; let test_name: String; let test_date: String; let result: String; let reference_range: String?; let icon: String?; let is_abnormal: Bool? }
struct MedHistoryDTO: Codable { let id: UUID; let condition: String; let diagnosed_date: String?; let status: String?; let doctor: String?; let notes: String?; let icon: String?; let color_hex: String? }
struct MedicationDTO: Codable { let id: UUID; let name: String; let dosage: String?; let frequency: String?; let next_dose: String?; let remaining: Int?; let total: Int?; let color_hex: String? }
struct AppNotifDTO: Codable { let id: UUID; let title: String; let message: String; let time_string: String?; let icon: String?; let color_hex: String?; let is_read: Bool? }

// MARK: - Core Data Store Configuration
@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()
    let client: SupabaseClient
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        let supabaseURL = URL(string: "https://kbsqbxhfewvguwtchwzp.supabase.co")!
        let supabaseKey = "sb_publishable_Ch-HXaqwI8oBcMXxZmAgJQ_Mh7TDRwX"
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password, data: ["first_name": .string(firstName), "last_name": .string(lastName)])
        self.currentUser = response.user; self.isAuthenticated = true
    }
    
    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        self.currentUser = response.user; self.isAuthenticated = true
    }
    
    func signOut() async throws { try await client.auth.signOut(); self.currentUser = nil; self.isAuthenticated = false }
    
    func signInWithGoogle() async throws -> URL {
        return try await client.auth.getOAuthSignInURL(provider: Provider.google, redirectTo: URL(string: "rwandacare://auth/callback"))
    }
    
    func fetchProfile() async throws -> UserProfile { guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }; return try await client.from("profiles").select().eq("id", value: userId).single().execute().value }
    func fetchFacilities() async throws -> [FacilityDTO] { return try await client.from("facilities").select().execute().value }
    func fetchDoctors() async throws -> [DoctorDTO] { return try await client.from("doctors").select().execute().value }
    func fetchAppointments() async throws -> [AppointmentDTO] { guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }; return try await client.from("appointments").select().eq("patient_id", value: userId).execute().value }
    func fetchLabResults() async throws -> [LabResultDTO] { guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }; return try await client.from("lab_results").select().eq("patient_id", value: userId).execute().value }
    func fetchMedHistory() async throws -> [MedHistoryDTO] { guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }; return try await client.from("medical_history").select().eq("patient_id", value: userId).execute().value }
    func fetchMedications() async throws -> [MedicationDTO] { guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }; return try await client.from("medications").select().eq("patient_id", value: userId).execute().value }
    func fetchNotifications() async throws -> [AppNotifDTO] { guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }; return try await client.from("notifications").select().eq("patient_id", value: userId).execute().value }
    
    func createAppointment(doctorName: String, specialty: String, hospital: String, date: String, time: String, appointmentID: String) async throws {
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        let newAppt = AppointmentInsertDTO(patient_id: userId, doctor_name: doctorName, specialty: specialty, hospital: hospital, appointment_date: date, appointment_time: time, appointment_id_string: appointmentID, status: "Upcoming")
        try await client.from("appointments").insert(newAppt).execute()
    }
}
