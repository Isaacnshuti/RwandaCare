import SwiftUI
import MapKit
import Combine

// ╔══════════════════════════════════════════════════════════════════╗
// ║                    RWANDACARE  — VERSION 4.0                     ║
// ║                Rwanda's Digital Health Companion                 ║
// ║           OFFLINE DEMO MODE (NO DATABASE REQUIRED)               ║
// ╚══════════════════════════════════════════════════════════════════╝

// ==========================================
// MARK: 0. GLOBAL HELPERS
// ==========================================

func callNumber(_ number: String) {
    let clean = number.filter { "0123456789+".contains($0) }
    if let url = URL(string: "tel://\(clean)") {
        UIApplication.shared.open(url)
    }
}

func openMaps(_ f: MedicalFacility) {
    let item = MKMapItem(placemark: MKPlacemark(coordinate: f.coordinate))
    item.name = f.name
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
}

// ==========================================
// MARK: 1. DESIGN SYSTEM
// ==========================================

extension Color {
    static let appBg         = Color(hex: "090E1A")
    static let appBgMid      = Color(hex: "0D1526")
    static let appCard       = Color(hex: "111C30")
    static let appCardBorder = Color(hex: "1E2D47")
    static let accentTeal    = Color(hex: "00D4AA")
    static let accentBlue    = Color(hex: "3B82F6")
    static let accentPurple  = Color(hex: "8B5CF6")
    static let accentRed     = Color(hex: "EF4444")
    static let accentOrange  = Color(hex: "F97316")
    static let accentGreen   = Color(hex: "22C55E")
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: "94A3B8")
    static let textMuted     = Color(hex: "475569")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 3: (r,g,b) = ((int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6: (r,g,b) = (int>>16, int>>8&0xFF, int&0xFF)
        default:(r,g,b) = (1,1,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: 1)
    }
}

extension LinearGradient {
    static let tealGrad   = LinearGradient(colors: [.accentTeal, .accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let redGrad    = LinearGradient(colors: [.accentRed, Color(hex:"991B1B")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let purpleGrad = LinearGradient(colors: [.accentPurple, .accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius)
            .shadow(color: color.opacity(0.2), radius: radius * 2)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 12) -> some View {
        self.modifier(GlowModifier(color: color, radius: radius))
    }
    
    func glassCard(border: Color = .appCardBorder) -> some View {
        self.background(Color.appCard)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    func animateIn(_ t: Bool, delay: Double = 0) -> some View {
        self.opacity(t ? 1 : 0)
            .offset(y: t ? 0 : 22)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: t)
    }
}

struct AppInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.appBgMid)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
            .foregroundColor(.textPrimary)
            .font(.system(size: 14, design: .rounded))
    }
}

struct PrimaryButton: ButtonStyle {
    var color: Color = .accentTeal
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(configuration.isPressed ? color.opacity(0.8) : color)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct OutlineButton: ButtonStyle {
    var color: Color = .accentTeal
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(0.08))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.4), lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct FieldLabel: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.textSecondary)
            .padding(.leading, 2)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.textPrimary)
    }
}

// ==========================================
// MARK: 2. DATA MODELS
// ==========================================

enum FacilityType: String, CaseIterable {
    case hospital = "Hospital", pharmacy = "Pharmacy", clinic = "Clinic"
    case dental = "Dental", eye = "Eye Care", lab = "Laboratory", healthPost = "Health Post"

    var icon: String {
        switch self {
        case .hospital: return "building.2.fill"
        case .pharmacy: return "pills.fill"
        case .clinic:   return "stethoscope"
        case .dental:   return "mouth.fill"
        case .eye:      return "eye.fill"
        case .lab:      return "testtube.2"
        case .healthPost: return "cross.case.fill"
        }
    }

    var color: Color {
        switch self {
        case .hospital:   return .accentRed
        case .pharmacy:   return .accentGreen
        case .clinic:     return Color(hex:"06B6D4")
        case .dental:     return Color(hex:"F0ABFC")
        case .eye:        return Color(hex:"34D399")
        case .lab:        return Color(hex:"FBBF24")
        case .healthPost: return .accentPurple
        }
    }
}

struct MedicalFacility: Identifiable {
    let id = UUID()
    let name, phone, address, district: String
    let type: FacilityType
    let coordinate: CLLocationCoordinate2D
    let isOpen24h: Bool
    let rating: Double
    let services: [String]
    var distanceKm: Double
    var icon: String { type.icon }
    var color: Color { type.color }
}

struct DoctorSlot: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let startsAt: String
    let endsAt: String
}

struct Doctor: Identifiable {
    let id = UUID()
    let name, specialty, hospital, experience, consultFee, imagePlaceholder: String
    let rating: Double
    let slots: [DoctorSlot]
}

struct Appointment: Identifiable {
    let id: UUID
    var doctorName, specialty, hospital, date, time, appointmentID: String
    var status: AStatus
    enum AStatus: String { case upcoming = "Upcoming"; case completed = "Completed"; case cancelled = "Cancelled" }
}

struct LabResult: Identifiable {
    let id = UUID()
    let testName, date, result, referenceRange, icon: String
    let isAbnormal: Bool
}

struct MedHistory: Identifiable {
    let id = UUID()
    let condition, diagnosedDate, status, doctor, notes, icon: String
    let color: Color
}

struct Medication: Identifiable {
    let id = UUID()
    let name, dosage, frequency, nextDose: String
    let remaining, total: Int
    let color: Color
}

struct AppNotif: Identifiable {
    let id = UUID()
    let title, message, time, icon: String
    let color: Color
    var isRead: Bool = false
}

struct NotifPref: Identifiable {
    let id = UUID()
    let title, subtitle, icon: String
    let color: Color
    var enabled: Bool
}

// ==========================================
// MARK: 3. APP STORE (MOCK DATA)
// ==========================================

class AppStore: ObservableObject {
    @Published var authMethod = "demo"
    @Published var firstName   = "Isaac"
    @Published var lastName    = "Nshuti"
    @Published var email       = "isaac.nshuti@rwandacare.rw"
    @Published var phone       = "+250 788 123 456"
    @Published var nationalID  = "1 1999 8 0023456 0 12"
    @Published var dateOfBirth = "15 / 08 / 1999"
    @Published var sex         = "M"
    @Published var address     = "Kigali, Gasabo"
    @Published var profession  = "Software Engineer"
    @Published var weight      = "72"
    @Published var height      = "178"
    @Published var bloodType   = "O+"
    @Published var insuranceNum = "RSSB-2026-9901"
    @Published var isVerified  = true

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var bmi: Double {
        let w = Double(weight.filter { "0123456789.".contains($0) }) ?? 70
        let h = (Double(height.filter { "0123456789.".contains($0) }) ?? 175) / 100
        return h > 0 ? w / (h * h) : 0
    }
    
    var bmiLabel: String {
        bmi < 18.5 ? "Underweight" : bmi < 25 ? "Normal" : bmi < 30 ? "Overweight" : "Obese"
    }
    
    var bmiColor: Color  {
        bmi < 18.5 ? .accentBlue : bmi < 25 ? .accentTeal : bmi < 30 ? .accentOrange : .accentRed
    }

    @Published var shareDataWithDoctors = true
    @Published var allowAnalytics = false
    @Published var twoFactorEnabled = true
    @Published var biometricLogin = true
    @Published var locationEnabled = true

    @Published var notifPrefs: [NotifPref] = [
        .init(title: "Appointment Reminders", subtitle: "24h before your visit", icon: "calendar.badge.clock", color: .accentBlue, enabled: true),
        .init(title: "Medication Reminders", subtitle: "At dose time every day", icon: "pills.fill", color: .accentOrange, enabled: true)
    ]

    @Published var appointments: [Appointment] = []
    @Published var labResults: [LabResult] = []
    @Published var medHistory: [MedHistory] = []
    @Published var medications: [Medication] = []
    @Published var notifications: [AppNotif] = []

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    
    func markAllRead() {
        for i in notifications.indices { notifications[i].isRead = true }
    }

    @MainActor
    func loadUserData() async {
        if DataStore.shared.isAuthenticated {
            do {
                if let _ = DataStore.shared.currentUser?.id {
                    let appts = try await DataStore.shared.fetchAppointments()
                    self.appointments = appts.map { dto in
                        let statusEnum: Appointment.AStatus
                        switch dto.status?.lowercased() {
                        case "completed": statusEnum = .completed
                        case "cancelled": statusEnum = .cancelled
                        default: statusEnum = .upcoming
                        }
                        return Appointment(id: dto.id, doctorName: dto.doctor_name, specialty: dto.specialty ?? "", hospital: dto.hospital ?? "", date: dto.appointment_date, time: dto.appointment_time, appointmentID: dto.appointment_id_string, status: statusEnum)
                    }
                }
            } catch {
                print("Failed to fetch live data: \(error)")
            }
        }
        
        if self.appointments.isEmpty {
            self.appointments = [
                Appointment(id: UUID(), doctorName: "Dr. Jean Kamanzi", specialty: "General Practitioner", hospital: "King Faisal Hospital", date: "April 15, 2026", time: "10:30 AM", appointmentID: "RDV-5592", status: .upcoming),
                Appointment(id: UUID(), doctorName: "Dr. Alice Uwase", specialty: "Cardiologist", hospital: "CHUK Teaching Hospital", date: "March 10, 2026", time: "02:00 PM", appointmentID: "RDV-4401", status: .completed)
            ]
        }

        self.labResults = [
            LabResult(testName: "Complete Blood Count", date: "Feb 14, 2026", result: "Normal", referenceRange: "4.5–11.0 ×10⁹/L", icon: "drop.fill", isAbnormal: false),
            LabResult(testName: "Blood Glucose (Fasting)", date: "Feb 14, 2026", result: "6.2 mmol/L", referenceRange: "3.9–5.6 mmol/L", icon: "chart.bar.fill", isAbnormal: true)
        ]

        self.medHistory = [
            MedHistory(condition: "Pre-diabetic (Type 2)", diagnosedDate: "Jan 2026", status: "Monitoring", doctor: "Dr. Kamanzi", notes: "Diet control and regular glucose monitoring.", icon: "chart.bar.fill", color: .accentOrange),
            MedHistory(condition: "Malaria (Uncomplicated)", diagnosedDate: "Aug 2023", status: "Resolved", doctor: "Dr. Mugabo", notes: "Treated with Coartem. Fully recovered.", icon: "cross.case.fill", color: .accentGreen)
        ]

        self.medications = [
            Medication(name: "Amlodipine", dosage: "5mg", frequency: "Once daily", nextDose: "8:00 AM", remaining: 18, total: 30, color: .accentRed),
            Medication(name: "Vitamin D3", dosage: "1000 IU", frequency: "Once daily", nextDose: "8:00 AM", remaining: 5, total: 30, color: .accentOrange)
        ]

        self.notifications = [
            AppNotif(title: "Lab Results Ready", message: "Your blood glucose result is available and needs attention.", time: "2h ago", icon: "doc.text.fill", color: .accentOrange, isRead: false),
            AppNotif(title: "Health Campaign", message: "Free flu vaccination available in all Kigali sectors.", time: "Yesterday", icon: "staroflife.fill", color: .accentPurple, isRead: true)
        ]
    }

    func clear() {
        authMethod = ""
        firstName = ""
        lastName = ""
        email = ""
        appointments = []
        labResults = []
        medHistory = []
        medications = []
        notifications = []
    }
}

// ==========================================
// MARK: 4. FACILITY DATABASE
// ==========================================

class FacilityDB: ObservableObject {
    @Published var all: [MedicalFacility] = []

    init() { loadMockData() }

    var hospitals:  [MedicalFacility] { all.filter { $0.type == .hospital  }.sorted { $0.distanceKm < $1.distanceKm } }
    var pharmacies: [MedicalFacility] { all.filter { $0.type == .pharmacy  }.sorted { $0.distanceKm < $1.distanceKm } }
    var specials:   [MedicalFacility] { all.filter { ![.hospital,.pharmacy].contains($0.type) }.sorted { $0.distanceKm < $1.distanceKm } }

    func loadMockData() {
        self.all = [
            MedicalFacility(name: "King Faisal Hospital", phone: "0252570114", address: "KG 544 St, Kacyiru", district: "Gasabo", type: .hospital, coordinate: CLLocationCoordinate2D(latitude: -1.9441, longitude: 30.0619), isOpen24h: true, rating: 4.8, services: ["Emergency", "Surgery", "ICU", "Cardiology"], distanceKm: 1.2),
            MedicalFacility(name: "CHUK Teaching Hospital", phone: "0252574522", address: "KN 4 Ave", district: "Nyarugenge", type: .hospital, coordinate: CLLocationCoordinate2D(latitude: -1.9545, longitude: 30.0574), isOpen24h: true, rating: 4.5, services: ["Emergency", "Teaching", "Surgery"], distanceKm: 3.4),
            MedicalFacility(name: "Rwanda Military Hospital", phone: "0252586017", address: "Kanombe", district: "Kicukiro", type: .hospital, coordinate: CLLocationCoordinate2D(latitude: -1.9750, longitude: 30.1200), isOpen24h: true, rating: 4.6, services: ["Emergency", "Trauma", "Orthopedics"], distanceKm: 8.1),
            MedicalFacility(name: "Vine Pharmacy", phone: "0788111000", address: "Kisimenti, Remera", district: "Gasabo", type: .pharmacy, coordinate: CLLocationCoordinate2D(latitude: -1.9520, longitude: 30.0900), isOpen24h: true, rating: 4.7, services: ["Prescription", "OTC", "Delivery"], distanceKm: 4.0),
            MedicalFacility(name: "MediHeal Diagnostic", phone: "0788555666", address: "Kagugu", district: "Gasabo", type: .lab, coordinate: CLLocationCoordinate2D(latitude: -1.9250, longitude: 30.0750), isOpen24h: false, rating: 4.5, services: ["Blood Tests", "MRI", "CT Scan"], distanceKm: 5.5),
            MedicalFacility(name: "Kigali Dental Clinic", phone: "0788121212", address: "KN 5 Ave", district: "Nyarugenge", type: .dental, coordinate: CLLocationCoordinate2D(latitude: -1.9470, longitude: 30.0610), isOpen24h: false, rating: 4.6, services: ["Dentistry", "Whitening"], distanceKm: 2.5)
        ]
    }
}

// ==========================================
// MARK: 5. DOCTOR DATABASE
// ==========================================

class DoctorDB: ObservableObject {
    @Published var all: [Doctor] = []

    init() { loadMockData() }

    func loadMockData() {
        let mockSlots = [
            DoctorSlot(label: "09:00 AM", startsAt: "", endsAt: ""),
            DoctorSlot(label: "10:30 AM", startsAt: "", endsAt: ""),
            DoctorSlot(label: "02:00 PM", startsAt: "", endsAt: ""),
            DoctorSlot(label: "04:30 PM", startsAt: "", endsAt: "")
        ]
        
        self.all = [
            Doctor(name: "Dr. Jean Kamanzi", specialty: "General Practitioner", hospital: "King Faisal Hospital", experience: "12 yrs", consultFee: "RWF 15,000", imagePlaceholder: "person.crop.circle.fill", rating: 4.9, slots: mockSlots),
            Doctor(name: "Dr. Alice Uwase", specialty: "Cardiologist", hospital: "CHUK Teaching Hospital", experience: "18 yrs", consultFee: "RWF 30,000", imagePlaceholder: "person.crop.circle.fill", rating: 4.8, slots: [mockSlots[0], mockSlots[2]]),
            Doctor(name: "Dr. Eric Mugabo", specialty: "Dermatologist", hospital: "La Croix du Sud", experience: "9 yrs", consultFee: "RWF 20,000", imagePlaceholder: "person.crop.circle.fill", rating: 4.7, slots: [mockSlots[1], mockSlots[3]]),
            Doctor(name: "Dr. Marie Ingabire", specialty: "Gynecologist", hospital: "Rwanda Military Hospital", experience: "14 yrs", consultFee: "RWF 25,000", imagePlaceholder: "person.crop.circle.fill", rating: 4.9, slots: mockSlots)
        ]
    }
}

// ==========================================
// MARK: 6. CONTENT VIEW
// ==========================================

struct ContentView: View {
    @StateObject var store = AppStore()
    @StateObject var db    = FacilityDB()
    @StateObject var docDB = DoctorDB()
    
    @State var scene: Scene = .splash
    enum Scene { case splash, auth, main }

    init() {
        let ta = UITabBarAppearance()
        ta.configureWithOpaqueBackground()
        ta.backgroundColor = UIColor(Color.appBgMid)
        ta.stackedLayoutAppearance.selected.iconColor = UIColor(Color.accentTeal)
        ta.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.accentTeal)]
        ta.stackedLayoutAppearance.normal.iconColor = UIColor(Color.textMuted)
        ta.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.textMuted)]
        UITabBar.appearance().standardAppearance = ta
        UITabBar.appearance().scrollEdgeAppearance = ta

        let na = UINavigationBarAppearance()
        na.configureWithOpaqueBackground()
        na.backgroundColor = UIColor(Color.appBg)
        na.titleTextAttributes = [.foregroundColor: UIColor.white]
        na.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = na
        UINavigationBar.appearance().scrollEdgeAppearance = na
        UINavigationBar.appearance().tintColor = UIColor(Color.accentTeal)
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            
            switch scene {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) { scene = .auth }
                }.transition(.opacity)
                
            case .auth:
                AuthView(store: store) {
                    Task {
                        await store.loadUserData()
                        await MainActor.run { withAnimation { scene = .main } }
                    }
                }.transition(.opacity)
                
            case .main:
                MainTabs(store: store, db: db, docDB: docDB) {
                    store.clear()
                    withAnimation { scene = .auth }
                }.transition(.opacity)
            }
        }.preferredColorScheme(.dark)
        .onOpenURL { url in
            Task {
                do {
                    try await DataStore.shared.client.auth.session(from: url)
                    await store.loadUserData()
                    withAnimation { scene = .main }
                } catch {
                    print("Auth error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// ==========================================
// MARK: 7. SPLASH
// ==========================================

struct SplashView: View {
    let onDone: () -> Void
    @State private var phase = 0

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            Circle()
                .fill(Color.accentTeal.opacity(0.10))
                .frame(width: 400).blur(radius: 90)
                .offset(x: -80, y: -200)
            
            Circle()
                .fill(Color.accentPurple.opacity(0.08))
                .frame(width: 300).blur(radius: 80)
                .offset(x: 100, y: 200)
            
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Color.accentTeal.opacity(0.12)).frame(width: 120)
                    Image(systemName: "staroflife.fill")
                        .resizable().scaledToFit().frame(width: 54)
                        .foregroundColor(.accentTeal).glow(.accentTeal, radius: 18)
                }
                .scaleEffect(phase >= 1 ? 1 : 0.4)
                .opacity(phase >= 1 ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: phase)

                Spacer().frame(height: 28)
                
                HStack(spacing: 0) {
                    Text("Rwanda").font(.system(size: 46, weight: .black, design: .rounded)).foregroundColor(.white)
                    Text("Care").font(.system(size: 46, weight: .black, design: .rounded)).foregroundColor(.accentTeal)
                }
                .offset(y: phase >= 2 ? 0 : 30)
                .opacity(phase >= 2 ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15), value: phase)

                Spacer().frame(height: 8)
                
                Text("HEALTH VISION 2050")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.textMuted).tracking(4)
                    .offset(y: phase >= 2 ? 0 : 20)
                    .opacity(phase >= 2 ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2), value: phase)

                Spacer().frame(height: 24)
                
                HStack(spacing: 8) {
                    Circle().fill(Color.accentGreen).frame(width: 7, height: 7)
                    Text("Connecting Rwanda to better healthcare").font(.system(size: 12, design: .rounded)).foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 18).padding(.vertical, 9)
                .background(Color.appCard).cornerRadius(100)
                .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.appCardBorder, lineWidth: 1))
                .offset(y: phase >= 3 ? 0 : 20)
                .opacity(phase >= 3 ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: phase)
            }
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { phase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { phase = 2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { phase = 3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { onDone() }
        }
    }
}

// ==========================================
// MARK: 8. AUTH VIEW
// ==========================================

struct AuthView: View {
    @ObservedObject var store: AppStore
    let onSuccess: () -> Void
    @Environment(\.openURL) var openURL
    
    @State private var isLogin = true
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nid = ""
    @State private var phoneField = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var agreed = false
    @State private var loading = false
    @State private var appeared = false
    @State private var errorMsg = ""
    @State private var showPwd = false
    @State private var showConfirm = false
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var bloodType = "O+"
    
    private let bloodTypes = ["O+","O-","A+","A-","B+","B-","AB+","AB-"]

    var canSubmit: Bool {
        if isLogin {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty && agreed && password == confirm
        }
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            Circle().fill(Color.accentTeal.opacity(0.06)).frame(width: 360).blur(radius: 90).offset(x: 120, y: -260)
            Circle().fill(Color.accentPurple.opacity(0.05)).frame(width: 300).blur(radius: 80).offset(x: -100, y: 320)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Spacer().frame(height: 40)
                        HStack(spacing: 8) {
                            Image(systemName: "staroflife.fill").foregroundColor(.accentTeal).font(.title3)
                            Text("RwandaCare").font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(.textPrimary)
                        }
                        VStack(spacing: 4) {
                            Text(isLogin ? "Welcome back" : "Create account").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.textPrimary).minimumScaleFactor(0.8)
                            Text(isLogin ? "Sign in to access your health records" : "Your digital health passport for Rwanda").font(.system(size: 13)).foregroundColor(.textSecondary).multilineTextAlignment(.center)
                        }
                    }.animateIn(appeared, delay: 0.05).padding(.horizontal, 24)

                    // Tab switcher
                    HStack(spacing: 0) {
                        AuthTab(label: "Sign In", active: isLogin)  { withAnimation(.spring()) { isLogin = true;  errorMsg = "" } }
                        AuthTab(label: "Sign Up", active: !isLogin) { withAnimation(.spring()) { isLogin = false; errorMsg = "" } }
                    }
                    .padding(3).background(Color.appCard).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(.horizontal, 24).padding(.top, 20).animateIn(appeared, delay: 0.08)

                    // Social buttons
                    VStack(spacing: 12) {
                        Button {
                            guard !loading else { return }
                            loading = true
                            Task {
                                do {
                                    let url = try await DataStore.shared.signInWithGoogle()
                                    openURL(url)
                                } catch {
                                    errorMsg = error.localizedDescription
                                }
                                loading = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.white).frame(width: 28, height: 28)
                                    Text("G").font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(LinearGradient(colors: [Color(hex:"4285F4"), Color(hex:"EA4335")], startPoint: .top, endPoint: .bottom))
                                }
                                Text("Continue with Google").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                if loading { Spacer(); ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8) }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 16)
                            .background(Color(hex: "1A1F2E")).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1.5))
                        }.opacity(loading ? 0.7 : 1).animation(.spring(response: 0.3), value: loading)

                        SocialButton(loading: loading) {
                            errorMsg = "Apple Sign In disabled in demo mode."
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "applelogo").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                                Text("Continue with Apple").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.black).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1.5))
                        }
                    }.padding(.horizontal, 24).padding(.top, 20).animateIn(appeared, delay: 0.10)

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder)
                        Text("or continue with email").font(.system(size: 12)).foregroundColor(.textMuted)
                        Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder)
                    }.padding(.horizontal, 24).padding(.vertical, 16).animateIn(appeared, delay: 0.12)

                    // Form fields
                    VStack(spacing: 12) {
                        if !isLogin {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) { FieldLabel("First Name"); AuthField("e.g. Isaac", text: $firstName) }
                                VStack(alignment: .leading, spacing: 4) { FieldLabel("Last Name");  AuthField("e.g. Nshuti", text: $lastName)  }
                            }
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) { FieldLabel("National ID"); AuthField("16 digits", text: $nid, keyboard: .numberPad) }
                                VStack(alignment: .leading, spacing: 4) { FieldLabel("Phone"); AuthField("+250...", text: $phoneField, keyboard: .phonePad) }
                            }
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    FieldLabel("Date of Birth")
                                    DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                                        .datePickerStyle(.compact).labelsHidden()
                                        .padding(.horizontal, 14).padding(.vertical, 13)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.appBgMid).cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    FieldLabel("Blood Type")
                                    Picker("Blood Type", selection: $bloodType) {
                                        ForEach(bloodTypes, id: \.self) { type in Text(type).tag(type) }
                                    }.pickerStyle(.menu)
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.appBgMid).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel("Email Address")
                            AuthField("your@email.com", text: $email, keyboard: .emailAddress, autoCapitalize: false)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel("Password")
                            AuthSecureField(placeholder: "Strong password", text: $password, show: $showPwd)
                        }
                        
                        if !isLogin {
                            VStack(alignment: .leading, spacing: 4) {
                                FieldLabel("Confirm Password")
                                AuthSecureField(placeholder: "Repeat password", text: $confirm, show: $showConfirm)
                            }
                            Button { agreed.toggle() } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: agreed ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 16)).foregroundColor(agreed ? .accentTeal : .textMuted)
                                    (Text("I agree to the ").foregroundColor(Color.textSecondary) + Text("Terms & Privacy Policy").foregroundColor(Color.accentTeal).bold())
                                        .font(.system(size: 12)).multilineTextAlignment(.leading)
                                    Spacer()
                                }
                            }.buttonStyle(.plain).padding(.top, 4)
                        }
                        
                        if !errorMsg.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.accentRed).font(.system(size: 13))
                                Text(errorMsg).font(.system(size: 12)).foregroundColor(.accentRed)
                                Spacer()
                            }
                            .padding(10).background(Color.accentRed.opacity(0.08)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentRed.opacity(0.25), lineWidth: 1))
                        }
                    }.padding(.horizontal, 24).animateIn(appeared, delay: 0.15)

                    VStack(spacing: 16) {
                        Button(action: handleSubmit) {
                            HStack(spacing: 10) {
                                if loading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)).scaleEffect(0.8) }
                                Text(isLogin ? "Sign In" : "Create Account")
                            }
                        }.buttonStyle(PrimaryButton()).opacity(canSubmit ? 1.0 : 0.45).disabled(!canSubmit)
                    }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 40).animateIn(appeared, delay: 0.18)
                }
            }
        }.onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appeared = true } }
    }

    func handleSubmit() {
        guard canSubmit else { return }
        if !isLogin && password != confirm { errorMsg = "Passwords don't match."; return }
        errorMsg = ""; loading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if !isLogin {
                store.firstName = firstName
                store.lastName = lastName
                store.email = email
            }
            loading = false
            onSuccess()
        }
    }
}

struct AuthTab: View {
    let label: String; let active: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? .black : .textSecondary)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(active ? Color.accentTeal : Color.clear).cornerRadius(11)
        }
    }
}

struct SocialButton<Label: View>: View {
    let loading: Bool; let action: () -> Void; @ViewBuilder let label: () -> Label
    var body: some View {
        Button(action: { if !loading { action() } }, label: label)
            .buttonStyle(.plain).opacity(loading ? 0.6 : 1)
    }
}

struct AuthField: View {
    let placeholder: String; @Binding var text: String
    var keyboard: UIKeyboardType = .default; var autoCapitalize: Bool = true
    
    init(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default, autoCapitalize: Bool = true) {
        self.placeholder = placeholder; self._text = text; self.keyboard = keyboard; self.autoCapitalize = autoCapitalize
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .autocapitalization(autoCapitalize ? .words : .none)
            .disableAutocorrection(true)
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color.appBgMid).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
            .foregroundColor(.textPrimary).font(.system(size: 14))
    }
}

struct AuthSecureField: View {
    let placeholder: String; @Binding var text: String; @Binding var show: Bool
    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if show { TextField(placeholder, text: $text).autocapitalization(.none).disableAutocorrection(true) }
                else    { SecureField(placeholder, text: $text) }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color.appBgMid).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
            .foregroundColor(.textPrimary).font(.system(size: 14))

            Button { show.toggle() } label: {
                Image(systemName: show ? "eye.slash" : "eye").foregroundColor(.textMuted).font(.system(size: 14)).padding(.trailing, 14)
            }
        }
    }
}

// ==========================================
// MARK: 9. MAIN TABS
// ==========================================

struct MainTabs: View {
    @ObservedObject var store: AppStore; @ObservedObject var db: FacilityDB; @ObservedObject var docDB: DoctorDB
    let onLogout: () -> Void
    var body: some View {
        TabView {
            NavigationView { HomeView(store: store, db: db, docDB: docDB) }.tabItem { Label("Home", systemImage: "house.fill") }
            NavigationView { AppointmentsView(store: store, db: db, docDB: docDB) }.tabItem { Label("Bookings", systemImage: "calendar") }
            NavigationView { MapView(db: db) }.tabItem { Label("Map", systemImage: "map.fill") }
            NavigationView { RecordsView(store: store) }.tabItem { Label("Records", systemImage: "doc.text.fill") }
            NavigationView { ProfileView(store: store, onLogout: onLogout) }.tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }.accentColor(.accentTeal)
    }
}

// ==========================================
// MARK: 10. HOME VIEW
// ==========================================

struct HomeView: View {
    @ObservedObject var store: AppStore; @ObservedObject var db: FacilityDB; @ObservedObject var docDB: DoctorDB
    @State private var showWizard = false; @State private var showNotifs = false; @State private var appeared = false
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            Circle().fill(Color.accentTeal.opacity(0.05)).frame(width: 350).blur(radius: 80).offset(x: 100, y: -100)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(greetingText()).font(.system(size: 14)).foregroundColor(.textSecondary)
                            Text(store.fullName).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
                        }
                        Spacer()
                        Button { showNotifs = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill").font(.system(size: 18)).foregroundColor(.textSecondary)
                                    .frame(width: 44, height: 44).background(Color.appCard).cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
                                if store.unreadCount > 0 {
                                    ZStack { Circle().fill(Color.accentRed).frame(width: 18); Text("\(store.unreadCount)").font(.system(size: 10, weight: .black)).foregroundColor(.white) }.offset(x: 4, y: -4)
                                }
                            }
                        }
                    }.padding(.horizontal, 20).padding(.top, 8).animateIn(appeared, delay: 0.05)

                    HealthSnapshot(store: store).padding(.horizontal, 20).animateIn(appeared, delay: 0.10)
                    TriageBanner { showWizard = true }.padding(.horizontal, 20).animateIn(appeared, delay: 0.16)

                    if let appt = store.appointments.filter({ $0.status == .upcoming }).first {
                        NextApptCard(appt: appt, db: db).padding(.horizontal, 20).animateIn(appeared, delay: 0.20)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("Quick Access").padding(.horizontal, 20)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            NavigationLink(destination: FacilityListView(title: "Pharmacies", items: db.pharmacies, accent: .accentGreen)) { ServiceTile(icon: "pills.fill", label: "Pharmacy", sub: "\(db.pharmacies.count) nearby", color: .accentGreen) }
                            NavigationLink(destination: EmergencyView()) { ServiceTile(icon: "exclamationmark.triangle.fill", label: "Emergency", sub: "Call 912 now", color: .accentRed) }
                            NavigationLink(destination: FacilityListView(title: "Hospitals", items: db.hospitals, accent: .accentBlue)) { ServiceTile(icon: "building.2.fill", label: "Hospitals", sub: "\(db.hospitals.count) found", color: .accentBlue) }
                            NavigationLink(destination: FacilityListView(title: "Clinics & Labs", items: db.specials, accent: .accentPurple)) { ServiceTile(icon: "stethoscope", label: "Clinics & Labs", sub: "\(db.specials.count) found", color: .accentPurple) }
                            NavigationLink(destination: DoctorSearchView(store: store, docDB: docDB)) { ServiceTile(icon: "person.fill.badge.plus", label: "Find a Doctor", sub: "\(docDB.all.count) available", color: .accentOrange) }
                            NavigationLink(destination: PreAdmissionView(store: store)) { ServiceTile(icon: "doc.badge.plus", label: "Pre-Admission", sub: "Fill form online", color: Color(hex:"06B6D4")) }
                        }.padding(.horizontal, 20)
                    }.animateIn(appeared, delay: 0.24)

                    if !store.medications.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                SectionTitle("Today's Medications").padding(.horizontal, 20)
                                Spacer()
                                NavigationLink(destination: MedicationsTab(store: store)) { Text("See all").font(.system(size: 13)).foregroundColor(.accentTeal).padding(.trailing, 20) }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) { ForEach(store.medications) { med in MedPill(med: med) } }.padding(.horizontal, 20)
                            }
                        }.animateIn(appeared, delay: 0.30)
                    }
                    Spacer(minLength: 30)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true } }
        .fullScreenCover(isPresented: $showWizard) { SymptomWizardView(isPresented: $showWizard, store: store, db: db, docDB: docDB) }
        .sheet(isPresented: $showNotifs) { NotificationsView(store: store, dismiss: { showNotifs = false }) }
    }

    func greetingText() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning," : h < 18 ? "Good afternoon," : "Good evening,"
    }
}

struct HealthSnapshot: View {
    @ObservedObject var store: AppStore
    var body: some View {
        HStack(spacing: 0) {
            SnapStat(v: String(format: "%.1f", store.bmi), l: "BMI", c: store.bmiColor)
            Divider().background(Color.appCardBorder).frame(height: 32)
            SnapStat(v: store.bloodType, l: "Blood", c: .accentRed)
            Divider().background(Color.appCardBorder).frame(height: 32)
            SnapStat(v: store.weight+"kg", l: "Weight", c: .accentPurple)
            Divider().background(Color.appCardBorder).frame(height: 32)
            SnapStat(v: store.height+"cm", l: "Height", c: .accentBlue)
        }.padding(.vertical, 4).glassCard()
    }
}

struct SnapStat: View {
    let v,l: String; let c: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(v).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(c)
            Text(l).font(.system(size: 10)).foregroundColor(.textMuted)
        }.frame(maxWidth: .infinity).padding(.vertical, 10)
    }
}

struct TriageBanner: View {
    let onTap: () -> Void; @State private var pulse = false
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [Color(hex: "042A30"), Color(hex: "071A2E")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.accentTeal.opacity(0.22), lineWidth: 1))
                Circle().fill(Color.accentTeal.opacity(0.18)).frame(width: 160).blur(radius: 40).offset(x: 90, y: 0)
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("AI Health Assessment", systemImage: "waveform.path.ecg").font(.system(size: 12, weight: .semibold)).foregroundColor(.accentTeal)
                        Text("Not feeling\nwell?").font(.system(size: 24, weight: .black, design: .rounded)).foregroundColor(.textPrimary).lineSpacing(2)
                        HStack(spacing: 8) {
                            Text("Check Symptoms").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.black)
                                .padding(.horizontal, 14).padding(.vertical, 9).background(Color.accentTeal).cornerRadius(100)
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundColor(.accentTeal)
                        }
                    }
                    Spacer()
                    Image(systemName: "stethoscope").font(.system(size: 58)).foregroundColor(.accentTeal.opacity(0.65))
                        .rotationEffect(.degrees(-15))
                        .scaleEffect(pulse ? 1.07 : 1).animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse = true }
                }.padding(22)
            }
        }.buttonStyle(.plain)
    }
}

struct NextApptCard: View {
    let appt: Appointment; @ObservedObject var db: FacilityDB
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Next Appointment", systemImage: "calendar.badge.clock").font(.system(size: 13, weight: .semibold)).foregroundColor(.accentBlue)
                Spacer()
                StatusBadge(text: "Upcoming", color: .accentGreen)
            }
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 42)).foregroundColor(.textMuted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appt.doctorName).font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                    Text(appt.specialty).font(.system(size: 13)).foregroundColor(.textSecondary)
                    HStack(spacing: 12) {
                        Label(appt.date, systemImage: "calendar").font(.system(size: 12)).foregroundColor(.textMuted)
                        Label(appt.time, systemImage: "clock").font(.system(size: 12)).foregroundColor(.textMuted)
                    }
                }
            }
            HStack {
                Label(appt.hospital, systemImage: "building.2").font(.system(size: 12)).foregroundColor(.textMuted).lineLimit(1)
                Spacer()
                Text("ID: \(appt.appointmentID)").font(.system(size: 11, design: .monospaced)).foregroundColor(.textMuted)
            }
        }.padding(18).glassCard(border: Color.accentBlue.opacity(0.2))
    }
}

struct ServiceTile: View {
    let icon, label, sub: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
                Text(sub).font(.system(size: 12)).foregroundColor(.textSecondary)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).glassCard()
    }
}

struct MedPill: View {
    let med: Medication
    var progress: Double { Double(med.remaining) / Double(med.total) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(med.color.opacity(0.18)).frame(width: 36, height: 36).overlay(Image(systemName: "pills.fill").font(.system(size: 14)).foregroundColor(med.color))
                Spacer()
                Text(med.nextDose).font(.system(size: 11, weight: .bold)).foregroundColor(.accentTeal).padding(.horizontal, 6).padding(.vertical, 3).background(Color.accentTeal.opacity(0.1)).cornerRadius(6)
            }
            Text(med.name).font(.system(size: 15, weight: .bold)).foregroundColor(.textPrimary)
            Text("\(med.dosage) · \(med.frequency)").font(.system(size: 12)).foregroundColor(.textSecondary)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 100).fill(Color.appCardBorder).frame(height: 4)
                    RoundedRectangle(cornerRadius: 100).fill(progress < 0.2 ? Color.accentRed : med.color).frame(width: g.size.width * progress, height: 4)
                }
            }.frame(height: 4)
            Text("\(med.remaining) pills left").font(.system(size: 11)).foregroundColor(med.remaining < 7 ? .accentRed : .textMuted)
        }.padding(16).frame(width: 185).glassCard()
    }
}

// ==========================================
// MARK: 11. FACILITY LIST + DETAIL
// ==========================================

struct FacilityListView: View {
    let title: String; let items: [MedicalFacility]; let accent: Color
    @State private var query = ""; @State private var only24h = false; @State private var selected: MedicalFacility? = nil
    var filtered: [MedicalFacility] {
        items.filter {
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.district.localizedCaseInsensitiveContains(query))
            && (!only24h || $0.isOpen24h)
        }
    }
    
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.textMuted)
                        TextField("Search by name or area…", text: $query).foregroundColor(.textPrimary).font(.system(size: 15))
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.textMuted) } }
                    }.padding(12).background(Color.appCard).cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
                    Button { only24h.toggle() } label: {
                        Image(systemName: only24h ? "clock.badge.checkmark.fill" : "clock").font(.system(size: 18)).foregroundColor(only24h ? .accentTeal : .textMuted)
                            .frame(width: 44, height: 44).background(Color.appCard).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(only24h ? Color.accentTeal.opacity(0.4) : Color.appCardBorder, lineWidth: 1))
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12)

                Text("\(filtered.count) place\(filtered.count == 1 ? "" : "s") found").font(.system(size: 12)).foregroundColor(.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if filtered.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "mappin.slash").font(.system(size: 40)).foregroundColor(.textMuted)
                                Text("No results found.").font(.system(size: 15)).foregroundColor(.textMuted)
                            }.padding(.top, 80)
                        } else {
                            ForEach(filtered) { f in Button { selected = f } label: { FacilityRow(f: f, accent: accent) }.buttonStyle(.plain) }
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.large).sheet(item: $selected) { f in FacilityDetailView(f: f, accent: accent) }
    }
}

struct FacilityRow: View {
    let f: MedicalFacility; let accent: Color
    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                Image(systemName: f.icon).font(.system(size: 20)).foregroundColor(accent)
                Text(String(format: "%.1f km", f.distanceKm)).font(.system(size: 10, weight: .bold)).foregroundColor(accent)
            }.frame(width: 60, height: 60).background(accent.opacity(0.1)).cornerRadius(16)

            VStack(alignment: .leading, spacing: 5) {
                Text(f.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary).lineLimit(1)
                Text(f.address).font(.system(size: 12)).foregroundColor(.textSecondary).lineLimit(1)
                HStack(spacing: 8) {
                    if f.isOpen24h {
                        HStack(spacing: 4) { Image(systemName: "clock.fill").foregroundColor(.accentGreen); Text("24h") }
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.accentGreen)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Color.accentGreen.opacity(0.12)).cornerRadius(6)
                    }
                    HStack(spacing: 2) { Image(systemName: "star.fill").foregroundColor(.accentOrange); Text(String(format: "%.1f", f.rating)) }
                        .font(.system(size: 10)).foregroundColor(.textMuted)
                }
            }
            Spacer()
            Button { openMaps(f) } label: {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill").font(.system(size: 32)).foregroundColor(accent)
            }.buttonStyle(.plain)
        }.padding(16).glassCard()
    }
}

struct FacilityDetailView: View {
    let f: MedicalFacility; let accent: Color; @Environment(\.presentationMode) var pres
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 14) {
                            ZStack { Circle().fill(accent.opacity(0.14)).frame(width: 100); Image(systemName: f.icon).font(.system(size: 44)).foregroundColor(accent) }
                            VStack(spacing: 5) {
                                Text(f.name).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.textPrimary).multilineTextAlignment(.center).padding(.horizontal, 20)
                                Text(f.type.rawValue.uppercased()).font(.system(size: 11, weight: .black)).tracking(2).foregroundColor(accent)
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").foregroundColor(.accentOrange)
                                    Text(String(format: "%.1f", f.rating)).font(.system(size: 15, weight: .bold)).foregroundColor(.textPrimary)
                                    Text("· \(f.district)").foregroundColor(.textMuted)
                                }.font(.system(size: 14))
                            }
                        }.padding(.top, 20)

                        HStack(spacing: 12) {
                            ActionPill(icon: "phone.fill",  label: "Call",       color: .accentGreen) { callNumber(f.phone) }
                            ActionPill(icon: "map.fill",    label: "Directions", color: .accentBlue)  { openMaps(f) }
                            if f.isOpen24h { ActionPill(icon: "clock.fill", label: "Open 24h", color: .accentTeal) {} }
                        }.padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 14) {
                            InfoRow(icon: "mappin.circle.fill",     label: "Address",  value: f.address, color: accent)
                            Divider().background(Color.appCardBorder)
                            InfoRow(icon: "phone.circle.fill",      label: "Phone",    value: f.phone, color: .accentGreen)
                            Divider().background(Color.appCardBorder)
                            InfoRow(icon: "mappin.and.ellipse",     label: "District", value: f.district, color: .accentBlue)
                            Divider().background(Color.appCardBorder)
                            InfoRow(icon: "location.circle.fill",   label: "Distance", value: String(format: "%.1f km from city center", f.distanceKm), color: .accentPurple)
                        }.padding(18).glassCard().padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Services Available").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(f.services, id: \.self) { svc in
                                    HStack(spacing: 8) {
                                        Circle().fill(accent.opacity(0.2)).frame(width: 8, height: 8)
                                        Text(svc).font(.system(size: 13)).foregroundColor(.textSecondary)
                                        Spacer()
                                    }.padding(.horizontal, 12).padding(.vertical, 8).background(Color.appCard).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                                }
                            }
                        }.padding(18).glassCard().padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Location on Map").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                            MiniMap(coord: f.coordinate, title: f.name).frame(height: 180).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
                        }.padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Facility Info").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }
        }
    }
}

struct MiniMap: UIViewRepresentable {
    let coord: CLLocationCoordinate2D; let title: String
    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView(); m.isScrollEnabled = false; m.isZoomEnabled = false
        m.setRegion(.init(center: coord, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)), animated: false)
        let pin = MKPointAnnotation(); pin.coordinate = coord; pin.title = title; m.addAnnotation(pin)
        return m
    }
    func updateUIView(_ v: MKMapView, context: Context) {}
}

struct ActionPill: View {
    let icon,label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.textSecondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 14).background(color.opacity(0.08)).cornerRadius(16)
             .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
        }
    }
}

struct InfoRow: View {
    let icon,label,value: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11)).foregroundColor(.textMuted).textCase(.uppercase).tracking(0.8)
                Text(value).font(.system(size: 14)).foregroundColor(.textPrimary)
            }
        }
    }
}

// ==========================================
// MARK: 12. APPOINTMENTS
// ==========================================

struct AppointmentsView: View {
    @ObservedObject var store: AppStore; @ObservedObject var db: FacilityDB; @ObservedObject var docDB: DoctorDB
    @State private var tab = 0; @State private var showBook = false

    var upcoming: [Appointment] { store.appointments.filter { $0.status == .upcoming } }
    var past:     [Appointment] { store.appointments.filter { $0.status != .upcoming } }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    SegBtn(label: "Upcoming (\(upcoming.count))", active: tab == 0) { tab = 0 }
                    SegBtn(label: "History (\(past.count))",     active: tab == 1) { tab = 1 }
                }.padding(4).background(Color.appCard).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1)).padding(.horizontal, 20).padding(.vertical, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        let list = tab == 0 ? upcoming : past
                        if list.isEmpty {
                            EmptyState(icon: tab == 0 ? "calendar.badge.plus" : "clock.arrow.circlepath", title: tab == 0 ? "No upcoming appointments" : "No history", subtitle: "Your visits will appear here.")
                            if tab == 0 {
                                Button { showBook = true } label: { Text("Book Appointment") }.buttonStyle(PrimaryButton()).frame(maxWidth: 240).padding(.top, 6)
                            }
                        } else {
                            ForEach(list) { a in ApptCard(appt: a, store: store, db: db) }
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("My Appointments").navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showBook = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(.accentTeal) } } }
        .sheet(isPresented: $showBook) { DoctorSearchView(store: store, docDB: docDB) }
    }
}

struct SegBtn: View {
    let label: String; let active: Bool; let action: () -> Void
    var body: some View {
        Button(action: { withAnimation(.spring()) { action() } }) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(active ? .black : .textSecondary).frame(maxWidth: .infinity).padding(.vertical, 11).background(active ? Color.accentTeal : Color.clear).cornerRadius(12)
        }
    }
}

struct ApptCard: View {
    let appt: Appointment; @ObservedObject var store: AppStore; @ObservedObject var db: FacilityDB
    @State private var confirmCancel = false

    var statusColor: Color { appt.status == .upcoming ? .accentBlue : appt.status == .completed ? .accentGreen : .accentRed }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                StatusBadge(text: appt.status.rawValue, color: statusColor)
                Spacer()
                Text("ID: \(appt.appointmentID)").font(.system(size: 11, design: .monospaced)).foregroundColor(.textMuted)
            }
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 44)).foregroundColor(.textMuted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appt.doctorName).font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                    Text(appt.specialty).font(.system(size: 13)).foregroundColor(.textSecondary)
                    Label(appt.hospital, systemImage: "building.2").font(.system(size: 11)).foregroundColor(.textMuted).lineLimit(1)
                }
            }
            HStack {
                Label(appt.date, systemImage: "calendar").font(.system(size: 13, weight: .medium)).foregroundColor(.textSecondary)
                Spacer()
                Label(appt.time, systemImage: "clock").font(.system(size: 13, weight: .medium)).foregroundColor(.textSecondary)
            }.padding(10).background(Color.appBgMid).cornerRadius(10)

            if appt.status == .upcoming {
                HStack(spacing: 10) {
                    Button { let number = db.all.first { $0.name == appt.hospital }?.phone ?? "912"; callNumber(number) } label: {
                        Label("Call Hospital", systemImage: "phone.fill").font(.system(size: 13, weight: .semibold)).foregroundColor(.accentGreen).frame(maxWidth: .infinity).padding(.vertical, 10).background(Color.accentGreen.opacity(0.08)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentGreen.opacity(0.25), lineWidth: 1))
                    }
                    Button { confirmCancel = true } label: {
                        Label("Cancel", systemImage: "xmark.circle").font(.system(size: 13, weight: .semibold)).foregroundColor(.accentRed).frame(maxWidth: .infinity).padding(.vertical, 10).background(Color.accentRed.opacity(0.07)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentRed.opacity(0.22), lineWidth: 1))
                    }
                }
            }
        }.padding(18).glassCard()
        .confirmationDialog("Cancel Appointment?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Yes, cancel it", role: .destructive) {
                if let i = store.appointments.firstIndex(where: { $0.id == appt.id }) {
                    withAnimation { store.appointments[i].status = .cancelled }
                }
            }
            Button("Keep it", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }
}

struct EmptyState: View {
    let icon,title,subtitle: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 48)).foregroundColor(.textMuted)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.textPrimary)
            Text(subtitle).font(.system(size: 14)).foregroundColor(.textSecondary).multilineTextAlignment(.center)
        }.padding(.top, 70)
    }
}

// ==========================================
// MARK: 13. DOCTOR SEARCH + BOOKING
// ==========================================

struct DoctorSearchView: View {
    @ObservedObject var store: AppStore; @ObservedObject var docDB: DoctorDB
    @Environment(\.presentationMode) var pres
    @State private var query = ""; @State private var filter = "All"; @State private var booking: Doctor? = nil

    let specialties = ["All","General Practitioner","Cardiologist","Neurologist","Pediatrician","Gynecologist","Dermatologist","Ophthalmologist","Internal Medicine"]

    var filtered: [Doctor] {
        docDB.all.filter {
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.specialty.localizedCaseInsensitiveContains(query))
            && (filter == "All" || $0.specialty == filter)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.textMuted)
                        TextField("Search doctor or specialty…", text: $query).foregroundColor(.textPrimary)
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.textMuted) } }
                    }.padding(12).background(Color.appCard).cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1)).padding(.horizontal, 20).padding(.top, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(specialties, id: \.self) { s in
                                Button { withAnimation { filter = s } } label: {
                                    Text(s).font(.system(size: 13, weight: .semibold)).foregroundColor(filter == s ? .black : .textSecondary).padding(.horizontal, 14).padding(.vertical, 8).background(filter == s ? Color.accentTeal : Color.appCard).cornerRadius(100).overlay(RoundedRectangle(cornerRadius: 100).stroke(filter == s ? Color.clear : Color.appCardBorder, lineWidth: 1))
                                }
                            }
                        }.padding(.horizontal, 20).padding(.vertical, 12)
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(filtered) { doc in
                                Button { booking = doc } label: { DoctorRow(doc: doc) }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 20).padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Find a Doctor").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }
            .sheet(item: $booking) { doc in BookingView(doc: doc, store: store, onDone: { pres.wrappedValue.dismiss() }) }
        }
    }
}

struct DoctorRow: View {
    let doc: Doctor
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: doc.imagePlaceholder).font(.system(size: 44)).foregroundColor(.textMuted).frame(width: 60, height: 60).background(Color.appBgMid).cornerRadius(16)
            VStack(alignment: .leading, spacing: 5) {
                Text(doc.name).font(.system(size: 15, weight: .bold)).foregroundColor(.textPrimary)
                Text(doc.specialty).font(.system(size: 13)).foregroundColor(.accentTeal)
                HStack(spacing: 6) {
                    HStack(spacing: 3) { Image(systemName: "star.fill").foregroundColor(.accentOrange); Text(String(format: "%.1f", doc.rating)).font(.system(size: 12)) }.foregroundColor(.textMuted)
                    Text("·").foregroundColor(.textMuted)
                    Text(doc.experience).font(.system(size: 12)).foregroundColor(.textMuted)
                }
                Text(doc.hospital).font(.system(size: 12)).foregroundColor(.textSecondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(doc.consultFee).font(.system(size: 12, weight: .bold)).foregroundColor(.accentGreen)
                StatusBadge(text: "Available", color: .accentGreen)
            }
        }.padding(16).glassCard()
    }
}

struct BookingView: View {
    let doc: Doctor; @ObservedObject var store: AppStore; let onDone: () -> Void
    @Environment(\.presentationMode) var pres
    @State private var selectedSlot: DoctorSlot? = nil
    @State private var reason = ""; @State private var done = false; @State private var bookingError = ""; @State private var saving = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                if done {
                    BookingSuccess(doc: doc, slot: selectedSlot?.label ?? "") { pres.wrappedValue.dismiss(); onDone() }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            HStack(spacing: 14) {
                                Image(systemName: doc.imagePlaceholder).font(.system(size: 48)).foregroundColor(.textMuted).frame(width: 70, height: 70).background(Color.appBgMid).cornerRadius(20)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(doc.name).font(.system(size: 18, weight: .bold)).foregroundColor(.textPrimary)
                                    Text(doc.specialty).font(.system(size: 14)).foregroundColor(.accentTeal)
                                    Text(doc.hospital).font(.system(size: 13)).foregroundColor(.textSecondary).lineLimit(1)
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill").foregroundColor(.accentOrange).font(.system(size: 12))
                                        Text(String(format: "%.1f", doc.rating)).font(.system(size: 13, weight: .bold)).foregroundColor(.textPrimary)
                                        Text("· \(doc.experience)").font(.system(size: 12)).foregroundColor(.textMuted)
                                    }
                                }
                            }.padding(18).glassCard()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Pick a Time Slot").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    ForEach(doc.slots) { option in
                                        Button { withAnimation { selectedSlot = option } } label: {
                                            Text(option.label).font(.system(size: 14, weight: .semibold)).foregroundColor(selectedSlot?.id == option.id ? .black : .textPrimary).frame(maxWidth: .infinity).padding(.vertical, 12).background(selectedSlot?.id == option.id ? Color.accentTeal : Color.appCard).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedSlot?.id == option.id ? Color.clear : Color.appCardBorder, lineWidth: 1))
                                        }
                                    }
                                }
                            }.padding(18).glassCard()

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Reason for Visit (optional)").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                                ZStack(alignment: .topLeading) {
                                    if reason.isEmpty { Text("e.g. chest pain, check-up…").font(.system(size: 14)).foregroundColor(.textMuted).padding(14) }
                                    TextEditor(text: $reason).frame(height: 100).padding(10).background(Color.appBgMid).cornerRadius(12).foregroundColor(.textPrimary).font(.system(size: 15))
                                }.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                            }.padding(18).glassCard()

                            HStack {
                                Text("Consultation Fee").font(.system(size: 15)).foregroundColor(.textSecondary)
                                Spacer()
                                Text(doc.consultFee).font(.system(size: 18, weight: .bold)).foregroundColor(.accentGreen)
                            }.padding(18).glassCard()

                            if !bookingError.isEmpty {
                                HStack(spacing: 10) { Image(systemName: "exclamationmark.circle.fill").foregroundColor(.accentRed); Text(bookingError).font(.system(size: 12)).foregroundColor(.accentRed); Spacer() }.padding(14).background(Color.accentRed.opacity(0.08)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentRed.opacity(0.25), lineWidth: 1))
                            }

                            Button {
                                guard let selectedSlot else { return }
                                bookingError = ""; saving = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    saving = false
                                    let newAppt = Appointment(id: UUID(), doctorName: doc.name, specialty: doc.specialty, hospital: doc.hospital, date: "April 18, 2026", time: selectedSlot.label, appointmentID: "RDV-\(Int.random(in: 1000...9999))", status: .upcoming)
                                    withAnimation { store.appointments.insert(newAppt, at: 0); done = true }
                                }
                            } label: {
                                HStack(spacing: 10) { if saving { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)).scaleEffect(0.8) }; Text("Confirm Booking") }
                            }.buttonStyle(PrimaryButton()).opacity(selectedSlot == nil || saving ? 0.45 : 1).disabled(selectedSlot == nil || saving)

                            Spacer(minLength: 30)
                        }.padding(20)
                    }
                }
            }
            .navigationTitle("Book Appointment").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }
        }
    }
}

struct BookingSuccess: View {
    let doc: Doctor; let slot: String; let onDone: () -> Void
    @State private var s = 0.3
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 80)).foregroundColor(.accentTeal).glow(.accentTeal, radius: 20).scaleEffect(s).onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { s = 1 } }
            Text("Booking Confirmed!").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
            VStack(spacing: 6) { Text(doc.name).font(.system(size: 17)).foregroundColor(.textSecondary); Text(slot).font(.system(size: 16, weight: .bold)).foregroundColor(.accentTeal); Text(doc.hospital).font(.system(size: 13)).foregroundColor(.textMuted) }
            Spacer()
            Button("Done", action: onDone).buttonStyle(PrimaryButton()).padding(.horizontal, 40).padding(.bottom, 40)
        }
    }
}

// ==========================================
// MARK: 14. MAP
// ==========================================

struct MapView: View {
    @ObservedObject var db: FacilityDB
    @State private var region = MKCoordinateRegion(center: .init(latitude: -1.9441, longitude: 30.0619), span: .init(latitudeDelta: 0.12, longitudeDelta: 0.12))
    @State private var filter: FacilityType? = nil
    @State private var tapped: MedicalFacility? = nil
    @State private var detail: MedicalFacility? = nil

    let chips: [(String, FacilityType?)] = [("All",nil),("Hospitals",.hospital),("Pharmacies",.pharmacy),("Labs",.lab),("Clinics",.clinic)]
    var shown: [MedicalFacility] { filter == nil ? db.all : db.all.filter { $0.type == filter } }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, annotationItems: shown) { f in
                MapAnnotation(coordinate: f.coordinate) {
                    Button { withAnimation { tapped = f } } label: {
                        VStack(spacing: 0) {
                            ZStack { Circle().fill(f.color).frame(width: 36, height: 36).shadow(color: f.color.opacity(0.5), radius: 6); Image(systemName: f.icon).font(.system(size: 16)).foregroundColor(.white) }
                            Triangle().fill(f.color).frame(width: 10, height: 6)
                        }
                    }.buttonStyle(.plain)
                }
            }.ignoresSafeArea()

            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(chips, id: \.0) { c in
                            Button { withAnimation { filter = c.1 } } label: {
                                Text(c.0).font(.system(size: 13, weight: .semibold)).foregroundColor(filter == c.1 ? .black : .textPrimary).padding(.horizontal, 14).padding(.vertical, 8).background(filter == c.1 ? Color.accentTeal : Color.appCard.opacity(0.95)).cornerRadius(100).overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.appCardBorder, lineWidth: 1))
                            }
                        }
                    }.padding(.horizontal, 20)
                }
                if let f = tapped {
                    MapBottomCard(f: f, onClose: { tapped = nil }, onDetail: { detail = f }).padding(.horizontal, 20).transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }.padding(.bottom, 16)
        }
        .navigationTitle("Nearby Facilities").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { f in FacilityDetailView(f: f, accent: f.color) }
    }
}

struct MapBottomCard: View {
    let f: MedicalFacility; let onClose: () -> Void; let onDetail: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: f.icon).font(.system(size: 24)).foregroundColor(f.color).frame(width: 52, height: 52).background(f.color.opacity(0.15)).cornerRadius(14)
            VStack(alignment: .leading, spacing: 4) {
                Text(f.name).font(.system(size: 15, weight: .bold)).foregroundColor(.textPrimary).lineLimit(1)
                Text(f.address).font(.system(size: 12)).foregroundColor(.textSecondary).lineLimit(1)
                HStack(spacing: 8) { Text(String(format: "%.1f km", f.distanceKm)).font(.system(size: 11, weight: .bold)).foregroundColor(f.color); if f.isOpen24h { Text("· 24h").font(.system(size: 11, weight: .bold)).foregroundColor(.accentGreen) } }
            }
            Spacer()
            VStack(spacing: 8) {
                Button { openMaps(f) } label: { Image(systemName: "arrow.triangle.turn.up.right.circle.fill").font(.system(size: 30)).foregroundColor(.accentBlue) }
                Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.textMuted) }
            }
        }.padding(16).glassCard()
    }
}

// ==========================================
// MARK: 15. HEALTH RECORDS
// ==========================================

struct RecordsView: View {
    @ObservedObject var store: AppStore
    @State private var tab = 0
    let tabs = ["Lab Results","Medical History","Medications"]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tabs.indices, id: \.self) { i in
                            Button { withAnimation(.spring()) { tab = i } } label: {
                                Text(tabs[i]).font(.system(size: 13, weight: .semibold)).foregroundColor(tab == i ? .black : .textSecondary).padding(.horizontal, 16).padding(.vertical, 8).background(tab == i ? Color.accentTeal : Color.appCard).cornerRadius(100).overlay(RoundedRectangle(cornerRadius: 100).stroke(tab == i ? Color.clear : Color.appCardBorder, lineWidth: 1))
                            }
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                }
                switch tab {
                case 0:  LabTab(store: store)
                case 1:  HistoryTab(store: store)
                default: MedicationsTab(store: store)
                }
            }
        }.navigationTitle("Health Records").navigationBarTitleDisplayMode(.large)
    }
}

struct LabTab: View {
    @ObservedObject var store: AppStore; @State private var detail: LabResult? = nil
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(store.labResults) { r in
                    Button { detail = r } label: {
                        HStack(spacing: 14) {
                            Image(systemName: r.icon).font(.system(size: 20)).foregroundColor(r.isAbnormal ? .accentOrange : .accentGreen).frame(width: 50, height: 50).background((r.isAbnormal ? Color.accentOrange : Color.accentGreen).opacity(0.12)).cornerRadius(14)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.testName).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                                Text(r.date).font(.system(size: 12)).foregroundColor(.textSecondary)
                                HStack(spacing: 5) { Circle().fill(r.isAbnormal ? Color.accentOrange : Color.accentGreen).frame(width: 6, height: 6); Text(r.isAbnormal ? "Needs attention" : "Normal").font(.system(size: 11, weight: .semibold)).foregroundColor(r.isAbnormal ? .accentOrange : .accentGreen) }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) { Text(r.result).font(.system(size: 14, weight: .bold)).foregroundColor(r.isAbnormal ? .accentOrange : .textPrimary); Text("View").font(.system(size: 12)).foregroundColor(.accentTeal) }
                        }.padding(16).glassCard()
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20).padding(.bottom, 30)
        }.sheet(item: $detail) { r in LabDetailSheet(r: r) }
    }
}

struct LabDetailSheet: View {
    let r: LabResult; @Environment(\.presentationMode) var pres
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                VStack(spacing: 24) {
                    ZStack { Circle().fill((r.isAbnormal ? Color.accentOrange : Color.accentGreen).opacity(0.12)).frame(width: 100); Image(systemName: r.icon).font(.system(size: 44)).foregroundColor(r.isAbnormal ? .accentOrange : .accentGreen) }.padding(.top, 20)
                    Text(r.testName).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.textPrimary).multilineTextAlignment(.center).padding(.horizontal, 20)
                    VStack(spacing: 14) {
                        DRow(label: "Result", value: r.result, highlight: r.isAbnormal)
                        Divider().background(Color.appCardBorder)
                        DRow(label: "Normal Range", value: r.referenceRange, highlight: false)
                        Divider().background(Color.appCardBorder)
                        DRow(label: "Test Date", value: r.date, highlight: false)
                    }.padding(18).glassCard().padding(.horizontal, 20)
                    if r.isAbnormal {
                        HStack(spacing: 12) { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.accentOrange); Text("Result outside normal range. Please consult your doctor soon.").font(.system(size: 13)).foregroundColor(.textSecondary) }.padding(16).background(Color.accentOrange.opacity(0.08)).cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentOrange.opacity(0.25), lineWidth: 1)).padding(.horizontal, 20)
                    }
                    Spacer()
                }
            }.navigationTitle("Lab Result").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }
        }
    }
}

struct DRow: View {
    let label,value: String; let highlight: Bool
    var body: some View { HStack { Text(label).font(.system(size: 13)).foregroundColor(.textMuted); Spacer(); Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(highlight ? .accentOrange : .textPrimary) } }
}

struct HistoryTab: View {
    @ObservedObject var store: AppStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                ForEach(store.medHistory) { h in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            Image(systemName: h.icon).font(.system(size: 22)).foregroundColor(h.color).frame(width: 50, height: 50).background(h.color.opacity(0.12)).cornerRadius(14)
                            VStack(alignment: .leading, spacing: 4) { Text(h.condition).font(.system(size: 15, weight: .bold)).foregroundColor(.textPrimary); Text("Diagnosed: \(h.diagnosedDate)").font(.system(size: 12)).foregroundColor(.textSecondary); StatusBadge(text: h.status, color: h.status == "Resolved" ? .accentGreen : h.status == "Controlled" ? .accentBlue : .accentOrange) }
                        }
                        HStack { Image(systemName: "person.crop.circle").foregroundColor(.textMuted); Text("Dr: \(h.doctor)").font(.system(size: 13)).foregroundColor(.textSecondary) }
                        Text(h.notes).font(.system(size: 13)).foregroundColor(.textSecondary).italic().padding(10).background(Color.appBgMid).cornerRadius(10)
                    }.padding(18).glassCard()
                }
            }.padding(.horizontal, 20).padding(.bottom, 30)
        }
    }
}

struct MedicationsTab: View {
    @ObservedObject var store: AppStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                ForEach(store.medications) { m in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            ZStack { Circle().fill(m.color.opacity(0.15)).frame(width: 52, height: 52); Image(systemName: "pills.fill").font(.system(size: 22)).foregroundColor(m.color) }
                            VStack(alignment: .leading, spacing: 4) { Text(m.name).font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary); Text("\(m.dosage) — \(m.frequency)").font(.system(size: 13)).foregroundColor(.textSecondary) }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) { Text("Next dose").font(.system(size: 10)).foregroundColor(.textMuted); Text(m.nextDose).font(.system(size: 14, weight: .bold)).foregroundColor(.accentTeal) }
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "pills").foregroundColor(.textMuted)
                            Text("\(m.remaining) of \(m.total) pills left").font(.system(size: 13)).foregroundColor(.textSecondary)
                            Spacer()
                            if m.remaining < 10 { StatusBadge(text: "Refill soon!", color: .accentRed) }
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 100).fill(Color.appCardBorder).frame(height: 6)
                                RoundedRectangle(cornerRadius: 100).fill(Double(m.remaining)/Double(m.total) < 0.2 ? Color.accentRed : m.color).frame(width: g.size.width * (Double(m.remaining)/Double(m.total)), height: 6)
                            }
                        }.frame(height: 6)
                    }.padding(18).glassCard()
                }
            }.padding(.horizontal, 20).padding(.bottom, 30)
        }
    }
}

// ==========================================
// MARK: 16. SYMPTOM WIZARD
// ==========================================

struct SymptomWizardView: View {
    @Binding var isPresented: Bool
    @ObservedObject var store: AppStore; @ObservedObject var db: FacilityDB; @ObservedObject var docDB: DoctorDB
    
    @State private var step = 0; @State private var syncing = true
    @State private var bpm = 0; @State private var spo2 = 0; @State private var temp = 0.0
    @State private var a_makes_worse = ""; @State private var a_feeling = ""; @State private var a_location = ""; @State private var pain = 5.0
    @State private var a_started = ""; @State private var a_symptoms = [String]()
    @State private var triageLevel = ""; @State private var triageColor = Color.accentBlue; @State private var triageAdvice = ""
    @State private var chosenFacility: MedicalFacility? = nil; @State private var chosenDoctor: Doctor? = nil; @State private var chosenSlot = ""

    let totalSteps = 9
    var progress: CGFloat { step > 0 && step < totalSteps ? CGFloat(step) / CGFloat(totalSteps) : 0 }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                VStack(spacing: 0) {
                    if step > 0 && step < totalSteps {
                        VStack(spacing: 10) {
                            HStack(spacing: 0) {
                                VitalChip(icon: "heart.fill",  val: "\(bpm)", unit: "bpm", bad: bpm > 100)
                                VitalChip(icon: "lungs.fill",  val: "\(spo2)", unit: "%",   bad: spo2 < 95)
                                VitalChip(icon: "thermometer", val: String(format: "%.1f", temp), unit: "°C", bad: temp > 38.0)
                            }.padding(.vertical, 4).background(Color.appCard).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder)).padding(.horizontal, 20)

                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 100).fill(Color.appCardBorder).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 100).fill(Color.accentTeal).frame(width: g.size.width * progress, height: 4).animation(.spring(response: 0.5), value: progress)
                                }
                            }.frame(height: 4).padding(.horizontal, 20)
                        }.padding(.top, 6).padding(.bottom, 10)
                    }

                    ScrollView(showsIndicators: false) {
                        switch step {
                        case 0: syncScreen
                        case 1: step1_emergency
                        case 2: step2_symptoms
                        case 3: step3_makesWorse
                        case 4: step4_feeling
                        case 5: step5_location
                        case 6: painStep
                        case 7: step7_started
                        case 8: facilityStep
                        default: finalScreen
                        }
                    }
                }
            }
            .navigationTitle(step > 0 && step < totalSteps ? "Step \(step) of \(totalSteps - 1)" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { if step < totalSteps { Button("Cancel") { isPresented = false }.foregroundColor(.textMuted) } }
                ToolbarItem(placement: .navigationBarTrailing) { if step > 1 && step < totalSteps { Button { withAnimation { step -= 1 } } label: { Image(systemName: "arrow.uturn.backward").foregroundColor(.textSecondary) } } }
            }
        }
    }

    func next() { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step += 1 } }

    var syncScreen: some View {
        VStack(spacing: 30) {
            Spacer().frame(height: 40)
            ZStack {
                Circle().fill(Color.accentTeal.opacity(0.1)).frame(width: 140)
                Image(systemName: syncing ? "applewatch" : "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(syncing ? .textMuted : .accentTeal).animation(.spring(), value: syncing)
            }
            VStack(spacing: 10) {
                Text(syncing ? "Reading your health data…" : "Vitals loaded!").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
                if syncing {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .accentTeal)).scaleEffect(1.3)
                    Text("Syncing with Apple Health").font(.system(size: 14)).foregroundColor(.textSecondary)
                } else {
                    Text("Ready! Let's understand what you are feeling.").font(.system(size: 14)).foregroundColor(.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 30)
                }
            }
        }.frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                bpm = Int.random(in: 68...112); spo2 = Int.random(in: 94...99); temp = Double.random(in: 36.4...38.4)
                withAnimation { syncing = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { next() }
            }
        }
    }

    var step1_emergency: some View { WizQuestion(label: "SAFETY CHECK", question: "Do you have any of these right now?", subtitle: "Tap everything that applies", choices: ["Severe difficulty breathing","Chest pain or pressure","Heavy uncontrolled bleeding","Cannot move or speak","None of the above"], multiSelect: true) { s in if s.contains("None of the above") { next() } else { isPresented = false; callNumber("912") } } }
    var step2_symptoms: some View { WizQuestion(label: "YOUR SYMPTOMS", question: "What are you feeling today?", subtitle: "You can pick more than one", choices: ["Headache or dizziness","Fever or chills","Stomach pain or nausea","Cough or sore throat","Pain somewhere in my body","Tiredness or weakness","Skin rash or itching","Something else"], multiSelect: true) { s in a_symptoms = s; next() } }
    var step3_makesWorse: some View { WizQuestion(label: "WHAT TRIGGERS IT", question: "What makes it feel worse?", subtitle: "Pick the one that fits best", choices: ["Moving around","Eating or drinking","Taking a deep breath","Nothing makes it worse","I don't know"], multiSelect: false) { s in a_makes_worse = s.first ?? ""; next() } }
    var step4_feeling: some View { WizQuestion(label: "HOW DOES IT FEEL", question: "How would you describe the pain?", subtitle: "Pick the closest description", choices: ["Sharp or stabbing","Dull and constant ache","Burning sensation","Tight or pressure feeling","Comes and goes","Hard to describe"], multiSelect: false) { s in a_feeling = s.first ?? ""; next() } }
    var step5_location: some View { WizQuestion(label: "WHERE IS IT", question: "Where in your body is the problem?", subtitle: "Pick the main area", choices: ["Head, neck or face","Chest or upper back","Belly or lower back","Arms or legs","All over my body","Hard to say"], multiSelect: false) { s in a_location = s.first ?? ""; next() } }

    var painStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            WizHeader(label: "PAIN LEVEL", question: "How bad is it right now?", subtitle: "1 = barely noticeable · 10 = worst pain ever")
            ZStack {
                Circle().fill(painColor.opacity(0.1)).frame(width: 120)
                VStack(spacing: 2) { Text("\(Int(pain))").font(.system(size: 52, weight: .black, design: .rounded)).foregroundColor(painColor); Text("out of 10").font(.system(size: 12)).foregroundColor(.textMuted) }
            }.frame(maxWidth: .infinity)
            Slider(value: $pain, in: 1...10, step: 1).tint(painColor).padding(.horizontal, 10)
            HStack { Text("1 — Very mild").font(.system(size: 12)).foregroundColor(.textMuted); Spacer(); Text("10 — Unbearable").font(.system(size: 12)).foregroundColor(.textMuted) }.padding(.horizontal, 4)
            Button { next() } label: { Text("Continue") }.buttonStyle(PrimaryButton()).padding(.top, 8)
        }.padding(24)
    }
    var painColor: Color { pain <= 3 ? .accentGreen : pain <= 6 ? .accentOrange : .accentRed }

    var step7_started: some View {
        WizQuestion(label: "HOW LONG", question: "How long have you had these symptoms?", subtitle: "This helps decide urgency", choices: ["Just started (less than 1 hour)","A few hours today","Started yesterday","For a few days","More than a week"], multiSelect: false) { s in a_started = s.first ?? ""; computeTriage(); next() }
    }

    var facilityStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR ASSESSMENT RESULT").font(.system(size: 11, weight: .black)).tracking(2).foregroundColor(.textMuted)
                HStack(spacing: 12) { Circle().fill(triageColor).frame(width: 12, height: 12); Text(triageLevel).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(triageColor) }
                Text(triageAdvice).font(.system(size: 14)).foregroundColor(.textSecondary)
            }.padding(18).glassCard(border: triageColor.opacity(0.35))

            Text("Choose a Hospital").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
            ForEach(db.hospitals.prefix(5)) { f in
                Button { chosenFacility = f } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "building.2.fill").font(.system(size: 20)).foregroundColor(.accentBlue).frame(width: 50, height: 50).background(Color.accentBlue.opacity(0.1)).cornerRadius(14)
                        VStack(alignment: .leading, spacing: 4) { Text(f.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary).lineLimit(1); Text(f.address).font(.system(size: 12)).foregroundColor(.textSecondary); if f.isOpen24h { StatusBadge(text: "Open 24h", color: .accentGreen) } }
                        Spacer()
                        ZStack { if chosenFacility?.id == f.id { Circle().fill(Color.accentTeal).frame(width: 28); Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.black) } else { Circle().stroke(Color.appCardBorder, lineWidth: 2).frame(width: 28) } }
                    }.padding(16).glassCard(border: chosenFacility?.id == f.id ? Color.accentTeal.opacity(0.4) : .appCardBorder)
                }.buttonStyle(.plain)
            }

            if chosenFacility != nil {
                Text("Pick a Doctor (optional)").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.textPrimary).padding(.top, 6)
                ForEach(docDB.all.prefix(3)) { doc in
                    Button { chosenDoctor = doc; chosenSlot = doc.slots.first?.label ?? ""; withAnimation { next() } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundColor(.textMuted)
                            VStack(alignment: .leading, spacing: 4) { Text(doc.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary); Text(doc.specialty).font(.system(size: 12)).foregroundColor(.textSecondary) }
                            Spacer()
                            Text(doc.slots.first?.label ?? "").font(.system(size: 12, weight: .bold)).foregroundColor(.accentGreen).padding(.horizontal, 8).padding(.vertical, 4).background(Color.accentGreen.opacity(0.1)).cornerRadius(8)
                        }.padding(16).glassCard()
                    }.buttonStyle(.plain)
                }
                Button { chosenDoctor = nil; withAnimation { next() } } label: {
                    Text("Skip — Just go to the hospital").font(.system(size: 14)).foregroundColor(.textMuted).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.appCard).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }
            Spacer(minLength: 30)
        }.padding(24)
    }

    var finalScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) { Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundColor(.accentTeal).glow(.accentTeal, radius: 16); Text("All done!").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.textPrimary); Text("Show this summary to the doctor when you arrive.").font(.system(size: 14)).foregroundColor(.textSecondary).multilineTextAlignment(.center) }
            VStack(spacing: 0) {
                HStack { HStack(spacing: 8) { Image(systemName: "staroflife.fill").foregroundColor(.accentTeal); VStack(alignment: .leading, spacing: 1) { Text("RWANDACARE").font(.system(size: 11, weight: .black)).foregroundColor(.black).tracking(1.5); Text("Patient Summary").font(.system(size: 10)).foregroundColor(.gray) } }; Spacer(); Image(systemName: "qrcode").resizable().scaledToFit().frame(width: 34).foregroundColor(.black) }.padding(16).background(Color.white); Divider()
                HStack { VStack(alignment: .leading, spacing: 3) { Text("PATIENT").font(.system(size: 9, weight: .bold)).foregroundColor(.gray); Text(store.fullName).font(.system(size: 16, weight: .bold)).foregroundColor(.black); Text("Blood: \(store.bloodType)  ·  BMI: \(String(format: "%.1f", store.bmi))").font(.system(size: 11)).foregroundColor(.gray) }; Spacer(); VStack(alignment: .trailing, spacing: 3) { Text("PRIORITY").font(.system(size: 9, weight: .bold)).foregroundColor(.gray); Text(triageLevel).font(.system(size: 12, weight: .black)).foregroundColor(triageColor).padding(.horizontal, 8).padding(.vertical, 4).background(triageColor.opacity(0.12)).cornerRadius(6) } }.padding(16).background(Color.white); Divider()
                HStack(spacing: 0) { MiniVital(l: "HR", v: "\(bpm) bpm", bad: bpm > 100); Divider().frame(height: 32); MiniVital(l: "SpO2", v: "\(spo2)%", bad: spo2 < 95); Divider().frame(height: 32); MiniVital(l: "TEMP", v: String(format: "%.1f°C", temp), bad: temp > 38.0) }.padding(.vertical, 8).background(Color(white: 0.96)); Divider()
                VStack(alignment: .leading, spacing: 8) { Text("MAIN COMPLAINT").font(.system(size: 9, weight: .bold)).foregroundColor(.gray); let symp = a_symptoms.filter { $0 != "None of the above" }.joined(separator: ", "); Text(symp.isEmpty ? "General discomfort" : symp).font(.system(size: 13)).foregroundColor(.black); if !a_feeling.isEmpty  { Text("Type: \(a_feeling)").font(.system(size: 12)).foregroundColor(.gray) }; if !a_location.isEmpty { Text("Location: \(a_location)").font(.system(size: 12)).foregroundColor(.gray) }; Text("Pain: \(Int(pain)) / 10  ·  Duration: \(a_started)").font(.system(size: 12)).foregroundColor(.gray) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.white); Divider()
                HStack { VStack(alignment: .leading, spacing: 3) { Text("GO TO").font(.system(size: 9, weight: .bold)).foregroundColor(.gray); Text(chosenFacility?.name ?? "Nearest ER").font(.system(size: 13, weight: .bold)).foregroundColor(.black); Text(chosenFacility?.address ?? "Kigali, Rwanda").font(.system(size: 10)).foregroundColor(.gray) }; Spacer(); if let doc = chosenDoctor { VStack(alignment: .trailing, spacing: 3) { Text("DOCTOR").font(.system(size: 9, weight: .bold)).foregroundColor(.gray); Text(doc.name).font(.system(size: 12, weight: .bold)).foregroundColor(.black); Text(chosenSlot).font(.system(size: 10)).foregroundColor(.gray) } } }.padding(14).background(Color.white)
            }.cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(triageColor.opacity(0.25), lineWidth: 1.5)).shadow(color: triageColor.opacity(0.2), radius: 24, y: 8).padding(.horizontal, 20)
            VStack(spacing: 12) { if let f = chosenFacility { Button { openMaps(f) } label: { Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill") }.buttonStyle(PrimaryButton()) }; Button { isPresented = false } label: { Text("Close") }.buttonStyle(OutlineButton()) }.padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    func computeTriage() {
        if pain >= 8 || a_location == "Chest or upper back" {
            triageLevel = "URGENT — Go now"; triageColor = .accentRed
            triageAdvice = "Your symptoms suggest emergency care is needed immediately. Go to the nearest hospital."
        } else if pain <= 3 && bpm < 95 && temp < 38 {
            triageLevel = "MILD — See a pharmacist"; triageColor = .accentGreen
            triageAdvice = "Your symptoms appear mild. A pharmacist may help with basic treatment."
        } else {
            triageLevel = "MODERATE — See a doctor"; triageColor = .accentOrange
            triageAdvice = "You should see a doctor today or tomorrow. Book an appointment or visit a clinic."
        }
    }
}

struct WizQuestion: View {
    let label,question,subtitle: String; let choices: [String]; let multiSelect: Bool
    let onDone: ([String]) -> Void
    @State private var picked = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            WizHeader(label: label, question: question, subtitle: subtitle)
            VStack(spacing: 10) {
                ForEach(choices, id: \.self) { c in
                    let selected = picked.contains(c)
                    Button {
                        if multiSelect { if selected { picked.remove(c) } else { picked.insert(c) } } else { picked = [c]; DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDone([c]) } }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack { RoundedRectangle(cornerRadius: multiSelect ? 7 : 14).fill(selected ? Color.accentTeal : Color.appBgMid).frame(width: 26, height: 26); if selected { Image(systemName: multiSelect ? "checkmark" : "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(.black) } }
                            Text(c).font(.system(size: 15, weight: .medium)).foregroundColor(.textPrimary); Spacer()
                        }.padding(16).background(selected ? Color.accentTeal.opacity(0.07) : Color.appCard).cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.accentTeal.opacity(0.6) : Color.appCardBorder, lineWidth: selected ? 1.5 : 1))
                    }.buttonStyle(.plain)
                }
                if multiSelect && !picked.isEmpty { Button { onDone(Array(picked)) } label: { Text("Continue →") }.buttonStyle(PrimaryButton()).padding(.top, 4) }
            }
        }.padding(24)
    }
}

struct WizHeader: View {
    let label,question,subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.system(size: 11, weight: .black)).tracking(2).foregroundColor(.accentTeal).padding(.horizontal, 10).padding(.vertical, 4).background(Color.accentTeal.opacity(0.12)).cornerRadius(6)
            Text(question).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.textPrimary).lineSpacing(3)
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 14)).foregroundColor(.textSecondary) }
        }
    }
}

struct VitalChip: View {
    let icon,val,unit: String; let bad: Bool
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(bad ? .accentRed : .textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) { Text(val).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(bad ? .accentRed : .textPrimary); Text(unit).font(.system(size: 10)).foregroundColor(.textMuted) }
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
    }
}

struct MiniVital: View {
    let l,v: String; let bad: Bool
    var body: some View { VStack(spacing: 3) { Text(l).font(.system(size: 9, weight: .bold)).foregroundColor(.gray); Text(v).font(.system(size: 13, weight: .bold)).foregroundColor(bad ? .red : .black) }.frame(maxWidth: .infinity) }
}

// ==========================================
// MARK: 17. EMERGENCY
// ==========================================

struct EmergencyView: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea(); Circle().fill(Color.accentRed.opacity(0.07)).frame(width: 500).blur(radius: 80)
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 12) { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundColor(.accentRed); Text("Emergency Services").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(.textPrimary); Text("Press the red button to call 912.\nYour GPS location will be shared automatically.").font(.system(size: 14)).foregroundColor(.textSecondary).multilineTextAlignment(.center) }
                Spacer().frame(height: 40)
                Button { callNumber("912") } label: {
                    ZStack {
                        Circle().fill(Color.accentRed.opacity(0.07)).frame(width: 224).scaleEffect(pulse ? 1.35 : 1)
                        Circle().fill(Color.accentRed.opacity(0.12)).frame(width: 192).scaleEffect(pulse ? 1.18 : 1)
                        Circle().fill(LinearGradient.redGrad).frame(width: 154).shadow(color: .accentRed.opacity(0.5), radius: 24)
                        VStack(spacing: 4) { Image(systemName: "phone.fill").font(.system(size: 28)).foregroundColor(.white); Text("SOS 912").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(.white) }
                    }
                }.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse).onAppear { pulse = true }
                Spacer().frame(height: 40)
                VStack(spacing: 12) { Text("Quick Contacts").font(.system(size: 14, weight: .semibold)).foregroundColor(.textSecondary); HStack(spacing: 12) { EmBtn(icon: "cross.case.fill", label: "Ambulance", num: "912", color: .accentRed) { callNumber("912") }; EmBtn(icon: "shield.fill", label: "Police", num: "100", color: .accentBlue) { callNumber("100") }; EmBtn(icon: "flame.fill", label: "Fire", num: "101", color: .accentOrange) { callNumber("101") } }.padding(.horizontal, 20) }
                Spacer()
                HStack(spacing: 6) { Image(systemName: "location.fill").foregroundColor(.accentTeal); Text("Location sharing is active").font(.system(size: 13)).foregroundColor(.textSecondary) }.padding(.bottom, 30)
            }.padding(.horizontal, 30)
        }.navigationTitle("Emergency SOS")
    }
}

struct EmBtn: View {
    let icon,label,num: String; let color: Color; let action: () -> Void
    var body: some View { Button(action: action) { VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 22)).foregroundColor(color); Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(.textPrimary); Text(num).font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(color) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(color.opacity(0.08)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1)) } }
}

// ==========================================
// MARK: 18. PRE-ADMISSION FORM
// ==========================================

struct PreAdmissionView: View {
    @ObservedObject var store: AppStore
    @State private var selectedHospital = "King Faisal Hospital"
    @State private var isRoutine = true; @State private var isIll = false
    @State private var symptoms = ""; @State private var agreed = false; @State private var submitted = false
    let hospitals = ["King Faisal Hospital","CHUK Teaching Hospital","Rwanda Military Hospital","Muhima District Hospital","La Croix du Sud","Baho International Hospital"]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            if submitted { FormDoneView() } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack { HStack(spacing: 8) { Image(systemName: "staroflife.fill").foregroundColor(.accentTeal); VStack(alignment: .leading, spacing: 1) { Text("RWANDACARE").font(.system(size: 10, weight: .black)).tracking(2).foregroundColor(.textPrimary); Text("Pre-Admission Form").font(.system(size: 11)).foregroundColor(.textSecondary) } }; Spacer(); VStack(alignment: .trailing) { Text("REF: FORM-2026").font(.system(size: 9, design: .monospaced)).foregroundColor(.textMuted); Text("DIGITAL").font(.system(size: 9, weight: .bold)).foregroundColor(.accentTeal).padding(.horizontal, 5).padding(.vertical, 2).background(Color.accentTeal.opacity(0.12)).cornerRadius(4) } }.padding(18).glassCard()

                        VStack(alignment: .leading, spacing: 12) {
                            FieldLabel("Select Hospital")
                            VStack(spacing: 2) { ForEach(hospitals, id: \.self) { h in Button { selectedHospital = h } label: { HStack { Image(systemName: selectedHospital == h ? "checkmark.circle.fill" : "circle").foregroundColor(selectedHospital == h ? .accentTeal : .textMuted); Text(h).font(.system(size: 14)).foregroundColor(.textPrimary); Spacer() }.padding(.vertical, 8).padding(.horizontal, 4) }.buttonStyle(.plain); if h != hospitals.last { Divider().background(Color.appCardBorder) } } }
                        }.padding(18).glassCard()

                        VStack(alignment: .leading, spacing: 12) { FieldLabel("Patient Information"); FRow(l: "Full Name", v: store.fullName); FRow(l: "Date of Birth", v: store.dateOfBirth); FRow(l: "Phone", v: store.phone); FRow(l: "Insurance", v: "RSSB / Mutuelle de Sante") }.padding(18).glassCard()

                        VStack(alignment: .leading, spacing: 12) { FieldLabel("Reason for Visit"); Toggle(isOn: $isRoutine) { Label("Routine checkup / Follow-up", systemImage: "checkmark.circle").foregroundColor(.textPrimary) }.toggleStyle(SwitchToggleStyle(tint: .accentTeal)); Divider().background(Color.appCardBorder); Toggle(isOn: $isIll) { Label("I have symptoms or feel sick", systemImage: "thermometer").foregroundColor(.textPrimary) }.toggleStyle(SwitchToggleStyle(tint: .accentTeal)) }.padding(18).glassCard()

                        VStack(alignment: .leading, spacing: 10) { FieldLabel("Describe your symptoms"); ZStack(alignment: .topLeading) { if symptoms.isEmpty { Text("e.g. Headache for 2 days, mild fever…").font(.system(size: 14)).foregroundColor(.textMuted).padding(14) }; TextEditor(text: $symptoms).frame(height: 110).padding(10).background(Color.appBgMid).cornerRadius(12).foregroundColor(.textPrimary).font(.system(size: 15)) }.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1)) }.padding(18).glassCard()

                        VStack(spacing: 14) { Button { agreed.toggle() } label: { HStack(alignment: .top, spacing: 10) { Image(systemName: agreed ? "checkmark.square.fill" : "square").font(.title3).foregroundColor(agreed ? .accentTeal : .textMuted); Text("I confirm that all information above is correct and accurate.").font(.system(size: 13)).foregroundColor(.textSecondary); Spacer() } }.buttonStyle(.plain); Button { withAnimation { submitted = true } } label: { Text("Submit Form") }.buttonStyle(PrimaryButton()).disabled(!agreed).opacity(agreed ? 1 : 0.45) }.padding(18).glassCard()
                        Spacer(minLength: 30)
                    }.padding(20)
                }
            }
        }.navigationTitle("Pre-Admission").navigationBarTitleDisplayMode(.inline)
    }
}

struct FRow: View { let l,v: String; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(l).font(.system(size: 11)).foregroundColor(.textMuted).textCase(.uppercase).tracking(0.8); Text(v.isEmpty ? "—" : v).font(.system(size: 15)).foregroundColor(.textPrimary); Divider().background(Color.appCardBorder) } } }

struct FormDoneView: View {
    @State private var s = 0.3
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 80)).foregroundColor(.accentTeal).glow(.accentTeal, radius: 20).scaleEffect(s).onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { s = 1 } }
            Text("Form Submitted!").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
            Text("Your pre-admission form has been sent. The hospital will contact you to confirm.").font(.system(size: 15)).foregroundColor(.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }
}

// ==========================================
// MARK: 19. NOTIFICATIONS
// ==========================================

struct NotificationsView: View {
    @ObservedObject var store: AppStore; let dismiss: () -> Void
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        if store.notifications.isEmpty {
                            EmptyState(icon: "bell.slash.fill", title: "No notifications", subtitle: "You're all caught up!")
                        } else {
                            ForEach(store.notifications) { n in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: n.icon).font(.system(size: 18)).foregroundColor(n.color).frame(width: 44, height: 44).background(n.color.opacity(0.12)).cornerRadius(14)
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack { Text(n.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary); if !n.isRead { Circle().fill(Color.accentTeal).frame(width: 8, height: 8) }; Spacer(); Text(n.time).font(.system(size: 11)).foregroundColor(.textMuted) }
                                        Text(n.message).font(.system(size: 13)).foregroundColor(.textSecondary).lineSpacing(3)
                                    }
                                }.padding(16).glassCard().opacity(n.isRead ? 0.7 : 1)
                            }
                        }
                    }.padding(20)
                }
            }
            .navigationTitle("Notifications").toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Mark all read") { store.markAllRead() }.font(.system(size: 13)).foregroundColor(.accentTeal) }; ToolbarItem(placement: .navigationBarTrailing) { Button("Done", action: dismiss).foregroundColor(.accentTeal) } }
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { store.markAllRead() } }
        }
    }
}

// ==========================================
// MARK: 20. PROFILE & SETTINGS
// ==========================================

struct ProfileView: View {
    @ObservedObject var store: AppStore
    let onLogout: () -> Void
    @State private var editing = false; @State private var showID = false; @State private var showInsurance = false
    @State private var showLogout = false; @State private var showNotifSettings = false; @State private var showPrivacy = false
    @State private var showHelp = false; @State private var showAbout = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            ZStack { Circle().fill(LinearGradient(colors: [Color.accentTeal.opacity(0.3), Color.accentPurple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 96, height: 96); Image(systemName: "person.fill").font(.system(size: 44)).foregroundColor(.textSecondary) }
                            if editing { Circle().fill(Color.accentTeal).frame(width: 28, height: 28).overlay(Image(systemName: "camera.fill").font(.system(size: 13)).foregroundColor(.black)).offset(x: 2, y: 2) }
                        }
                        Text(store.fullName).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
                        if editing { TextField("Profession", text: $store.profession).multilineTextAlignment(.center).textFieldStyle(AppInputStyle()).frame(width: 220) } else { Text(store.profession).font(.system(size: 14)).foregroundColor(.textSecondary) }
                        if store.isVerified { HStack(spacing: 6) { Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundColor(.accentTeal); Text("NIDA Verified").font(.system(size: 12, weight: .semibold)).foregroundColor(.accentTeal) }.padding(.horizontal, 12).padding(.vertical, 5).background(Color.accentTeal.opacity(0.1)).cornerRadius(100) }
                    }.padding(.top, 28)

                    HStack(spacing: 0) {
                        PStat(v: "\(store.appointments.filter { $0.status == .upcoming }.count)", l: "Upcoming")
                        Divider().background(Color.appCardBorder).frame(height: 36)
                        PStat(v: "\(store.appointments.filter { $0.status == .completed }.count)", l: "Completed")
                        Divider().background(Color.appCardBorder).frame(height: 36)
                        PStat(v: "\(store.labResults.count)", l: "Lab Tests")
                        Divider().background(Color.appCardBorder).frame(height: 36)
                        PStat(v: "\(store.medications.count)", l: "Meds")
                    }.padding(.vertical, 6).glassCard().padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Digital Wallet").padding(.horizontal, 20)
                        Button { showID = true } label: { WRow(icon: "person.text.rectangle.fill", title: "National ID (E-Indangamuntu)", sub: "Tap to view your digital ID", color: .accentBlue) }.buttonStyle(.plain).padding(.horizontal, 20)
                        Button { showInsurance = true } label: { WRow(icon: "cross.case.fill", title: "RSSB / Mutuelle de Sante", sub: "Insurance card — Active", color: .accentGreen) }.buttonStyle(.plain).padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack { SectionTitle("Official Info"); Spacer(); Image(systemName: "lock.fill").foregroundColor(.textMuted) }.padding(.horizontal, 20)
                        VStack(spacing: 0) { LockedR(l: "National ID", v: store.nationalID); Divider().background(Color.appCardBorder).padding(.horizontal, 18); LockedR(l: "Date of Birth", v: store.dateOfBirth); Divider().background(Color.appCardBorder).padding(.horizontal, 18); LockedR(l: "Sex", v: store.sex) }.glassCard().padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack { SectionTitle("Health Data").padding(.horizontal, 20); Spacer(); Button { withAnimation(.spring()) { editing.toggle() } } label: { Text(editing ? "Save" : "Edit").font(.system(size: 14, weight: .semibold)).foregroundColor(.accentTeal).padding(.trailing, 20) } }
                        HStack(spacing: 12) { ECard(icon: "scalemass.fill", title: "Weight", unit: "kg", value: $store.weight, color: .accentOrange, editing: editing); ECard(icon: "ruler.fill", title: "Height", unit: "cm", value: $store.height, color: .accentPurple, editing: editing); ECard(icon: "drop.fill", title: "Blood", unit: "", value: $store.bloodType, color: .accentRed, editing: editing) }.padding(.horizontal, 20)
                        HStack(spacing: 12) { Image(systemName: "chart.bar.fill").foregroundColor(.accentTeal); VStack(alignment: .leading, spacing: 2) { Text("BMI — Calculated automatically").font(.system(size: 13)).foregroundColor(.textPrimary); Text(store.bmiLabel).font(.system(size: 11)).foregroundColor(.textSecondary) }; Spacer(); Text(String(format: "%.1f", store.bmi)).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(store.bmiColor) }.padding(16).glassCard().padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Account").padding(.horizontal, 20)
                        VStack(spacing: 0) {
                            Button { showNotifSettings = true } label: { SRow(icon: "bell.fill", label: "Notifications", color: .accentBlue) }
                            Divider().background(Color.appCardBorder).padding(.horizontal, 18)
                            Button { showPrivacy = true } label: { SRow(icon: "lock.shield.fill", label: "Privacy & Security", color: .accentPurple) }
                            Divider().background(Color.appCardBorder).padding(.horizontal, 18)
                            Button { showHelp = true } label: { SRow(icon: "questionmark.circle.fill",label: "Help & Support", color: .accentOrange) }
                            Divider().background(Color.appCardBorder).padding(.horizontal, 18)
                            Button { showAbout = true } label: { SRow(icon: "info.circle.fill", label: "About RwandaCare", color: .accentTeal) }
                        }.glassCard().padding(.horizontal, 20)
                    }

                    Button { showLogout = true } label: { HStack(spacing: 8) { Image(systemName: "arrow.right.square.fill"); Text("Sign Out") }.font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.accentRed).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.accentRed.opacity(0.07)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentRed.opacity(0.2), lineWidth: 1)) }.padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }.navigationBarHidden(true)
        .sheet(isPresented: $showID) { DigitalIDView(store: store) }
        .sheet(isPresented: $showInsurance) { InsuranceView(store: store) }
        .sheet(isPresented: $showNotifSettings) { NotifSettingsView(store: store) }
        .sheet(isPresented: $showPrivacy) { PrivacyView(store: store) }
        .sheet(isPresented: $showHelp) { HelpView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .confirmationDialog("Sign out of RwandaCare?", isPresented: $showLogout, titleVisibility: .visible) { Button("Sign Out", role: .destructive, action: onLogout); Button("Cancel", role: .cancel) {} }
    }
}

struct PStat: View { let v,l: String; var body: some View { VStack(spacing: 4) { Text(v).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.accentTeal); Text(l).font(.system(size: 10)).foregroundColor(.textMuted) }.frame(maxWidth: .infinity).padding(.vertical, 10) } }
struct WRow: View { let icon,title,sub: String; let color: Color; var body: some View { HStack(spacing: 14) { Image(systemName: icon).font(.title2).foregroundColor(color).frame(width: 50, height: 50).background(color.opacity(0.12)).cornerRadius(14); VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary); Text(sub).font(.system(size: 12)).foregroundColor(.accentGreen) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.textMuted) }.padding(16).glassCard() } }
struct LockedR: View { let l,v: String; var body: some View { HStack { VStack(alignment: .leading, spacing: 4) { Text(l).font(.system(size: 11, weight: .medium)).foregroundColor(.textMuted).textCase(.uppercase).tracking(0.8); Text(v.isEmpty ? "—" : v).font(.system(size: 15)).foregroundColor(.textPrimary) }; Spacer(); Image(systemName: "lock.fill").font(.system(size: 11)).foregroundColor(.textMuted) }.padding(.horizontal, 18).padding(.vertical, 14) } }
struct ECard: View { let icon,title,unit: String; @Binding var value: String; let color: Color; let editing: Bool; var body: some View { VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 18)).foregroundColor(color); if editing { TextField("", text: $value).multilineTextAlignment(.center).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.textPrimary).frame(width: 50).padding(4).background(Color.appBgMid).cornerRadius(8) } else { Text(value + unit).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.textPrimary) }; Text(title).font(.system(size: 10)).foregroundColor(.textMuted) }.frame(maxWidth: .infinity).padding(.vertical, 14).glassCard() } }
struct SRow: View { let icon,label: String; let color: Color; var body: some View { HStack(spacing: 14) { Image(systemName: icon).font(.system(size: 16)).foregroundColor(color).frame(width: 36, height: 36).background(color.opacity(0.1)).cornerRadius(10); Text(label).font(.system(size: 15)).foregroundColor(.textPrimary); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.textMuted) }.padding(.horizontal, 18).padding(.vertical, 12) } }

// ==========================================
// MARK: 21. PROFILE SUB-VIEWS
// ==========================================

struct NotifSettingsView: View {
    @ObservedObject var store: AppStore; @Environment(\.presentationMode) var pres
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(spacing: 14) { ZStack { Circle().fill(Color.accentBlue.opacity(0.15)).frame(width: 52, height: 52); Image(systemName: "bell.badge.fill").font(.system(size: 22)).foregroundColor(.accentBlue) }; VStack(alignment: .leading, spacing: 3) { Text("Push Notifications").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary); Text("Receive alerts on your device").font(.system(size: 13)).foregroundColor(.textSecondary) }; Spacer(); Toggle("", isOn: .constant(true)).toggleStyle(SwitchToggleStyle(tint: .accentTeal)).labelsHidden() }.padding(18).glassCard()
                        Text("Notification Types").font(.system(size: 14, weight: .semibold)).foregroundColor(.textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4).padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(store.notifPrefs.indices, id: \.self) { i in
                                HStack(spacing: 14) { Image(systemName: store.notifPrefs[i].icon).font(.system(size: 16)).foregroundColor(store.notifPrefs[i].color).frame(width: 38, height: 38).background(store.notifPrefs[i].color.opacity(0.12)).cornerRadius(10); VStack(alignment: .leading, spacing: 3) { Text(store.notifPrefs[i].title).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary); Text(store.notifPrefs[i].subtitle).font(.system(size: 12)).foregroundColor(.textMuted) }; Spacer(); Toggle("", isOn: $store.notifPrefs[i].enabled).toggleStyle(SwitchToggleStyle(tint: .accentTeal)).labelsHidden() }.padding(.horizontal, 18).padding(.vertical, 12)
                                if i < store.notifPrefs.count - 1 { Divider().background(Color.appCardBorder).padding(.horizontal, 18) }
                            }
                        }.glassCard()
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quiet Hours").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                            Text("No notifications will be sent between 10 PM and 7 AM.").font(.system(size: 13)).foregroundColor(.textSecondary)
                            HStack(spacing: 16) { VStack(alignment: .leading, spacing: 4) { Text("FROM").font(.system(size: 10, weight: .bold)).foregroundColor(.textMuted).tracking(1); Text("10:00 PM").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.textPrimary) }.frame(maxWidth: .infinity).padding(14).background(Color.appBgMid).cornerRadius(12); Image(systemName: "arrow.right").foregroundColor(.textMuted); VStack(alignment: .leading, spacing: 4) { Text("TO").font(.system(size: 10, weight: .bold)).foregroundColor(.textMuted).tracking(1); Text("7:00 AM").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.textPrimary) }.frame(maxWidth: .infinity).padding(14).background(Color.appBgMid).cornerRadius(12) }
                        }.padding(18).glassCard()
                        Spacer(minLength: 30)
                    }.padding(20)
                }
            }.navigationTitle("Notifications").navigationBarTitleDisplayMode(.large).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }
        }
    }
}

struct PrivacyView: View {
    @ObservedObject var store: AppStore; @Environment(\.presentationMode) var pres; @State private var showDeleteConfirm = false
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) { Text("Security").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary); VStack(spacing: 0) { ToggleRow(icon: "faceid", title: "Face ID / Biometric Login", sub: "Use Face ID to sign in faster", color: .accentBlue, binding: $store.biometricLogin); Divider().background(Color.appCardBorder).padding(.horizontal, 18); ToggleRow(icon: "lock.rotation", title: "Two-Factor Authentication", sub: "Extra layer of account security", color: .accentGreen, binding: $store.twoFactorEnabled); Divider().background(Color.appCardBorder).padding(.horizontal, 18); ToggleRow(icon: "location.fill", title: "Location Access", sub: "For finding nearby hospitals", color: .accentOrange, binding: $store.locationEnabled) }.glassCard() }
                        VStack(alignment: .leading, spacing: 14) { Text("Data & Privacy").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary); VStack(spacing: 0) { ToggleRow(icon: "person.2.fill", title: "Share Data with Doctors", sub: "Allow doctors to see your health records", color: .accentTeal, binding: $store.shareDataWithDoctors); Divider().background(Color.appCardBorder).padding(.horizontal, 18); ToggleRow(icon: "chart.bar.doc.horizontal", title: "Analytics", sub: "Help improve RwandaCare", color: .accentPurple, binding: $store.allowAnalytics) }.glassCard(); Text("Your health data is encrypted and stored securely. We never sell your personal information to third parties.").font(.system(size: 12)).foregroundColor(.textMuted).padding(.top, 4) }
                        VStack(alignment: .leading, spacing: 14) { Text("Account").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary); VStack(spacing: 0) { PrivacyNavRow(icon: "key.fill", title: "Change Password", sub: "Update your login password", color: .accentBlue); Divider().background(Color.appCardBorder).padding(.horizontal, 18); PrivacyNavRow(icon: "envelope.fill", title: "Change Email", sub: store.email, color: .accentGreen); Divider().background(Color.appCardBorder).padding(.horizontal, 18); PrivacyNavRow(icon: "eye.slash.fill", title: "Blocked Users", sub: "Manage blocked contacts", color: .accentOrange) }.glassCard() }
                        VStack(alignment: .leading, spacing: 14) { Text("Legal").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary); VStack(spacing: 0) { PrivacyNavRow(icon: "doc.text.fill", title: "Privacy Policy", sub: "How we handle your data", color: .accentTeal); Divider().background(Color.appCardBorder).padding(.horizontal, 18); PrivacyNavRow(icon: "scroll.fill", title: "Terms of Service", sub: "Our user agreement", color: .accentPurple); Divider().background(Color.appCardBorder).padding(.horizontal, 18); PrivacyNavRow(icon: "person.badge.shield.checkmark", title: "GDPR / Data Rights", sub: "Request export or deletion", color: .accentBlue) }.glassCard() }
                        Button { showDeleteConfirm = true } label: { HStack(spacing: 10) { Image(systemName: "trash.fill"); Text("Delete My Account") }.font(.system(size: 14, weight: .semibold)).foregroundColor(.accentRed).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.accentRed.opacity(0.07)).cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentRed.opacity(0.2), lineWidth: 1)) }
                        Spacer(minLength: 30)
                    }.padding(20)
                }
            }.navigationTitle("Privacy & Security").navigationBarTitleDisplayMode(.large).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }.confirmationDialog("Delete your account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) { Button("Delete permanently", role: .destructive) { pres.wrappedValue.dismiss() }; Button("Cancel", role: .cancel) {} } message: { Text("All your health data will be removed. This cannot be undone.") }
        }
    }
}
struct ToggleRow: View { let icon,title,sub: String; let color: Color; @Binding var binding: Bool; var body: some View { HStack(spacing: 14) { Image(systemName: icon).font(.system(size: 16)).foregroundColor(color).frame(width: 38, height: 38).background(color.opacity(0.12)).cornerRadius(10); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary); Text(sub).font(.system(size: 12)).foregroundColor(.textMuted) }; Spacer(); Toggle("", isOn: $binding).toggleStyle(SwitchToggleStyle(tint: .accentTeal)).labelsHidden() }.padding(.horizontal, 18).padding(.vertical, 12) } }
struct PrivacyNavRow: View { let icon,title,sub: String; let color: Color; var body: some View { HStack(spacing: 14) { Image(systemName: icon).font(.system(size: 16)).foregroundColor(color).frame(width: 38, height: 38).background(color.opacity(0.12)).cornerRadius(10); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary); Text(sub).font(.system(size: 12)).foregroundColor(.textMuted) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.textMuted) }.padding(.horizontal, 18).padding(.vertical, 12) } }

struct HelpView: View {
    @Environment(\.presentationMode) var pres; @State private var expandedFAQ: String? = nil
    let faqs: [(String,String)] = [("How do I book a doctor?", "Go to the Bookings tab or tap 'Find a Doctor' on the Home screen. Pick a specialist, select a time slot, and confirm. You'll receive a booking confirmation immediately."), ("How do I cancel an appointment?", "Open the Bookings tab, find your upcoming appointment, and tap the Cancel button. You can cancel up to 2 hours before your scheduled time."), ("What is the AI Health Check?", "The AI Health Check on the Home screen asks you a series of simple questions about your symptoms and gives you a recommended next step — pharmacy, doctor, or emergency room."), ("How do I update my health data?", "Go to Profile tab, scroll to 'Health Data', and tap Edit. You can update your weight, height, and blood type. Save when done."), ("Is my data secure?", "Yes. All your health data is encrypted using AES-256 and stored on secure servers. We are fully compliant with Rwanda's Data Protection Law."), ("How do I get directions to a hospital?", "Tap any hospital or pharmacy card, then tap the Directions button. It will open Apple Maps with turn-by-turn navigation."), ("How does the Emergency button work?", "Tapping SOS 912 immediately calls Rwanda's emergency services. Your GPS location is shared automatically with the dispatcher."), ("Can I share my records with a doctor?", "Yes. Go to Profile > Privacy & Security and enable 'Share Data with Doctors'. Your doctor will then have access during your consultation.")]
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) { Text("Contact Us").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary); HStack(spacing: 12) { ContactCard(icon: "phone.fill", label: "Call Us", sub: "+250 788 000 000", color: .accentGreen) { callNumber("250788000000") }; ContactCard(icon: "envelope.fill", label: "Email", sub: "support@rwandacare.rw", color: .accentBlue) {} }; HStack(spacing: 12) { ContactCard(icon: "message.fill", label: "Live Chat", sub: "Mon–Fri 8AM–6PM", color: .accentTeal) {}; ContactCard(icon: "globe", label: "Website", sub: "rwandacare.rw", color: .accentPurple) {} } }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Frequently Asked Questions").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                            VStack(spacing: 8) {
                                ForEach(faqs, id: \.0) { faq in
                                    VStack(spacing: 0) { Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { expandedFAQ = expandedFAQ == faq.0 ? nil : faq.0 } } label: { HStack { Text(faq.0).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary).multilineTextAlignment(.leading); Spacer(); Image(systemName: expandedFAQ == faq.0 ? "chevron.up" : "chevron.down").font(.system(size: 12)).foregroundColor(.textMuted) }.padding(16) }.buttonStyle(.plain); if expandedFAQ == faq.0 { Text(faq.1).font(.system(size: 13)).foregroundColor(.textSecondary).lineSpacing(4).padding(.horizontal, 16).padding(.bottom, 14) } }.background(Color.appCard).cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
                                }
                            }
                        }
                        VStack(spacing: 6) { Text("RwandaCare v4.0").font(.system(size: 13, weight: .semibold)).foregroundColor(.textMuted); Text("Built for Rwanda · Health Vision 2050").font(.system(size: 11)).foregroundColor(.textMuted) }.frame(maxWidth: .infinity).padding(.top, 8)
                        Spacer(minLength: 30)
                    }.padding(20)
                }
            }.navigationTitle("Help & Support").navigationBarTitleDisplayMode(.large).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }
        }
    }
}
struct ContactCard: View { let icon,label,sub: String; let color: Color; let action: () -> Void; var body: some View { Button(action: action) { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).font(.system(size: 22)).foregroundColor(color); Text(label).font(.system(size: 14, weight: .bold)).foregroundColor(.textPrimary); Text(sub).font(.system(size: 11)).foregroundColor(.textSecondary).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).glassCard() } } }

struct AboutView: View {
    @Environment(\.presentationMode) var pres
    let team: [(String,String,String)] = [("stethoscope", "Medical Advisory", "Partnered with Kigali physicians"), ("building.2.fill", "Hospital Network", "30+ facilities across Kigali"), ("lock.shield.fill", "Data Security", "AES-256 encrypted, GDPR compliant"), ("globe.africa.fill", "Mission", "Universal health access for Rwanda")]
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea(); Circle().fill(Color.accentTeal.opacity(0.05)).frame(width: 300).blur(radius: 60).offset(x: 80, y: -100)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) { ZStack { Circle().fill(Color.accentTeal.opacity(0.15)).frame(width: 100); Image(systemName: "staroflife.fill").resizable().scaledToFit().frame(width: 48).foregroundColor(.accentTeal).glow(.accentTeal, radius: 12) }; (Text("Rwanda").font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(.white) + Text("Care").font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(.accentTeal)); Text("HEALTH VISION 2050").font(.system(size: 11, weight: .black)).tracking(3).foregroundColor(.textMuted); Text("Version 4.0.0 (2026)").font(.system(size: 13)).foregroundColor(.textSecondary) }.padding(.top, 20)
                        VStack(spacing: 10) { Text("Our Mission").font(.system(size: 18, weight: .bold)).foregroundColor(.textPrimary); Text("RwandaCare connects every Rwandan citizen to quality healthcare through technology. We make it easy to find hospitals, book doctors, manage prescriptions, and access your health records — all from your phone.").font(.system(size: 14)).foregroundColor(.textSecondary).multilineTextAlignment(.center).lineSpacing(4) }.padding(20).glassCard().padding(.horizontal, 20)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What we offer").font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(team, id: \.1) { item in VStack(alignment: .leading, spacing: 10) { Image(systemName: item.0).font(.system(size: 24)).foregroundColor(.accentTeal); Text(item.1).font(.system(size: 14, weight: .bold)).foregroundColor(.textPrimary); Text(item.2).font(.system(size: 11)).foregroundColor(.textSecondary) }.padding(16).frame(maxWidth: .infinity, alignment: .leading).glassCard() }
                            }
                        }.padding(.horizontal, 20)
                        HStack(spacing: 0) { AboutStat(v: "30+", l: "Hospitals"); Divider().background(Color.appCardBorder).frame(height: 36); AboutStat(v: "10+", l: "Pharmacies"); Divider().background(Color.appCardBorder).frame(height: 36); AboutStat(v: "8", l: "Doctors"); Divider().background(Color.appCardBorder).frame(height: 36); AboutStat(v: "24/7",l: "Emergency") }.padding(.vertical, 6).glassCard().padding(.horizontal, 20)
                        VStack(spacing: 4) { Text("Made with ❤️ for Rwanda").font(.system(size: 13)).foregroundColor(.textSecondary); Text("© 2026 RwandaCare. All rights reserved.").font(.system(size: 11)).foregroundColor(.textMuted); Text("Kigali, Rwanda").font(.system(size: 11)).foregroundColor(.textMuted) }.padding(.top, 8).padding(.bottom, 40)
                    }
                }
            }.navigationTitle("About").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal) } }
        }
    }
}
struct AboutStat: View { let v,l: String; var body: some View { VStack(spacing: 4) { Text(v).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.accentTeal); Text(l).font(.system(size: 10)).foregroundColor(.textMuted) }.frame(maxWidth: .infinity).padding(.vertical, 10) } }

// ==========================================
// MARK: 22. WALLET CARDS
// ==========================================

struct DigitalIDView: View {
    @ObservedObject var store: AppStore; @Environment(\.presentationMode) var pres
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.appCardBorder).frame(width: 40, height: 4).padding(.top, 16).padding(.bottom, 24)
                Text("National ID Card").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
                Spacer().frame(height: 30)
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(hex: "0D1F5C"), Color(hex: "163B6B")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1)
                    Circle().fill(Color.white.opacity(0.03)).frame(width: 200).offset(x: 80, y: -80)
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { VStack(alignment: .leading) { Text("REPUBLIC OF RWANDA").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7)).tracking(1.5); Text("NATIONAL ID").font(.system(size: 15, weight: .black)).foregroundColor(.white).tracking(1) }; Spacer(); Image(systemName: "seal.fill").font(.system(size: 28)).foregroundColor(Color(hex: "FFD700").opacity(0.8)) }
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)).frame(width: 70, height: 90).overlay(Image(systemName: "person.fill").font(.system(size: 36)).foregroundColor(.white.opacity(0.5)))
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) { Text("NID NUMBER").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.5)).tracking(1); Text(store.nationalID).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "FFD700")) }
                                VStack(alignment: .leading, spacing: 2) { Text("NAMES").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.5)).tracking(1); Text(store.fullName).font(.system(size: 14, weight: .bold)).foregroundColor(.white) }
                                HStack(spacing: 14) { VStack(alignment: .leading, spacing: 2) { Text("SEX").font(.system(size: 9)).foregroundColor(.white.opacity(0.5)); Text(store.sex).font(.system(size: 12, weight: .bold)).foregroundColor(.white) }; VStack(alignment: .leading, spacing: 2) { Text("DOB").font(.system(size: 9)).foregroundColor(.white.opacity(0.5)); Text(store.dateOfBirth).font(.system(size: 12, weight: .bold)).foregroundColor(.white) } }
                            }
                        }
                    }.padding(24)
                }.frame(height: 220).padding(.horizontal, 24).shadow(color: .blue.opacity(0.4), radius: 30, y: 10)
                Spacer()
                Button("Close") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal).padding(.bottom, 40)
            }
        }
    }
}

struct InsuranceView: View {
    @ObservedObject var store: AppStore; @Environment(\.presentationMode) var pres
    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.appCardBorder).frame(width: 40, height: 4).padding(.top, 16).padding(.bottom, 24)
                Text("Insurance Card").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
                Spacer().frame(height: 30)
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(hex: "0D4A30"), Color(hex: "0A2A50")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1)
                    Circle().fill(Color.accentGreen.opacity(0.06)).frame(width: 200).offset(x: 80, y: -60)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text("RSSB").font(.system(size: 22, weight: .black)).foregroundColor(.white); Spacer(); Text("ACTIVE").font(.system(size: 10, weight: .black)).foregroundColor(.accentGreen).padding(.horizontal, 8).padding(.vertical, 4).background(Color.accentGreen.opacity(0.15)).cornerRadius(6) }
                        Text("MUTUELLE DE SANTE").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.7)).tracking(1.5)
                        Spacer()
                        Text(store.insuranceNum).font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "7FE8C4"))
                        HStack { VStack(alignment: .leading, spacing: 2) { Text("MEMBER").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.5)).tracking(1); Text(store.fullName).font(.system(size: 14, weight: .bold)).foregroundColor(.white) }; Spacer(); Image(systemName: "qrcode").resizable().frame(width: 36, height: 36).foregroundColor(.white) }
                    }.padding(24)
                }.frame(height: 220).padding(.horizontal, 24).shadow(color: .green.opacity(0.3), radius: 30, y: 10)
                Spacer()
                Button("Close") { pres.wrappedValue.dismiss() }.foregroundColor(.accentTeal).padding(.bottom, 40)
            }
        }
    }
}

// ==========================================
// MARK: 23. PREVIEW
// ==========================================

struct ContentView_Previews: PreviewProvider { static var previews: some View { ContentView() } }
