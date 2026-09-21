import SwiftUI
import UIKit
import UserNotifications

// MARK: - Custom Colors
extension Color {
    static var amoledBackground: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .black : .systemGray6
        })
    }
}

// MARK: - Data Models
enum TaskColor: String, Codable, CaseIterable {
    case standard, blue, red, green, orange
    
    var uiColor: Color {
        switch self {
        case .standard: return .primary
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .orange: return .orange
        }
    }
}

struct Task: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var date: Date
    var isImportant: Bool
    var color: TaskColor?
    var completedDate: Date?
}

extension Task {
    var extractedURL: URL? {
        if title.lowercased().hasPrefix("http://") || title.lowercased().hasPrefix("https://") {
            return URL(string: title.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

// MARK: - App Features: Haptic Feedback
func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

// MARK: - App Features: Custom Press Animation
struct TaskPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Welcome Page (Splash Screen)
struct SplashView: View {
    @State private var isActive = false
    @State private var opacity: Double = 0.0
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                Color.amoledBackground
                    .ignoresSafeArea()
                
                Text("Todoy")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .opacity(opacity)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    self.opacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

// MARK: - Page Enumeration
enum TaskPage {
    case today
    case upcoming
}

// MARK: - Main View
struct ContentView: View {
    @State private var tasks: [Task] = []
    
    @State private var showingAddTask = false
    @State private var newTaskIsImportant = false
    @State private var selectedPage: TaskPage = .today
    
    @State private var taskToEdit: Task?
    @State private var showingCompletedTasks = false
    
    @State private var activeMenuTask: Task? = nil
    @State private var activeMenuFrame: CGRect = .zero
    
    let saveKey = "SavedTasks"
    
    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.systemGray]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.systemGray]
    }
    
    var currentTasks: [Task] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        let filteredTasks = tasks.filter { task in
            if task.isCompleted, let cDate = task.completedDate {
                if Date().timeIntervalSince(cDate) > 86400 { return false }
            }
            if selectedPage == .today {
                return task.date < startOfTomorrow
            } else {
                return task.date >= startOfTomorrow
            }
        }
        
        return filteredTasks.sorted {
            if $0.isCompleted == $1.isCompleted {
                return $0.date < $1.date
            }
            return !$0.isCompleted && $1.isCompleted
        }
    }
    
    var todayString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.amoledBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(selectedPage == .today ? "Today" : "Upcoming")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.gray)
                            .contentTransition(.opacity)
                        
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedPage = selectedPage == .today ? .upcoming : .today
                            }
                            triggerHaptic(style: .light)
                        } label: {
                            Text(selectedPage == .today ? "Upcoming" : "Today")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.gray.opacity(0.4))
                                .contentTransition(.opacity)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                    
                    List {
                        ForEach(currentTasks) { task in
                            TaskRowView(
                                task: task,
                                onTap: { toggleTask(task) },
                                onLongPress: { frame in
                                    activeMenuFrame = frame
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        activeMenuTask = task
                                    }
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                            
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    toggleImportant(task)
                                } label: {
                                    let isRed = task.color == .red || task.isImportant
                                    Label(isRed ? "Unmark" : "Important", systemImage: isRed ? "star.slash.fill" : "star.fill")
                                }
                                .tint(.orange)
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    
                    HStack(alignment: .center, spacing: 16) {
                        Spacer()
                        
                        Text(todayString.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Button {
                            newTaskIsImportant = false
                            showingAddTask = true
                            triggerHaptic(style: .light)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.primary)
                                .shadow(color: .primary.opacity(0.1), radius: 5, y: 5)
                        }
                        .contextMenu {
                            Button {
                                newTaskIsImportant = true
                                showingAddTask = true
                                triggerHaptic(style: .medium)
                            } label: {
                                Label("Add Important Task", systemImage: "star.fill")
                            }
                            
                            Button {
                                pasteTaskFromClipboard()
                            } label: {
                                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            }
                            
                            Divider()
                            
                            Button {
                                showingCompletedTasks = true
                                triggerHaptic(style: .light)
                            } label: {
                                Label("Insights & History", systemImage: "chart.bar.fill")
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.amoledBackground.opacity(0.0), Color.amoledBackground]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                }
                
                // MARK: - THE LIQUID GLASS OVERLAY MENU
                if let task = activeMenuTask {
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.01)
                            .background(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeMenu()
                            }
                        
                        HStack(alignment: .center, spacing: 8) {
                            Text(task.title)
                                .font(.system(size: 22, weight: task.isCompleted ? .regular : .bold, design: .default))
                                .strikethrough(task.isCompleted, color: .gray)
                                .foregroundColor(task.isCompleted ? .gray : (task.color?.uiColor ?? (task.isImportant ? .red : .primary)))
                                .lineLimit(2)
                            Spacer()
                        }
                        .frame(width: activeMenuFrame.width, height: activeMenuFrame.height)
                        .offset(x: activeMenuFrame.minX, y: activeMenuFrame.minY)
                        .zIndex(2)
                        
                        let opensUpwards = activeMenuFrame.maxY + 320 > UIScreen.main.bounds.height
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Due: \(task.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            
                            Divider().opacity(0.5)
                            
                            VStack(spacing: 0) {
                                MenuRow(title: "Edit Task", icon: "pencil") {
                                    closeMenu()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { taskToEdit = task }
                                }
                                Divider().opacity(0.5)
                                
                                if let validURL = task.extractedURL {
                                    MenuRow(title: "Open Link", icon: "safari") {
                                        UIApplication.shared.open(validURL)
                                        closeMenu()
                                    }
                                    Divider().opacity(0.5)
                                }
                                
                                MenuRow(title: (task.color == .red || task.isImportant) ? "Unmark Important" : "Mark Important", icon: (task.color == .red || task.isImportant) ? "star.slash" : "star") {
                                    toggleImportant(task)
                                    closeMenu()
                                }
                                Divider().opacity(0.5)
                                
                                MenuRow(title: "Duplicate Task", icon: "plus.square.on.square") {
                                    duplicateTask(task)
                                    closeMenu()
                                }
                                Divider().opacity(0.5)
                                
                                MenuRow(title: "Copy Text", icon: "doc.on.doc") {
                                    UIPasteboard.general.string = task.title
                                    triggerHaptic(style: .light)
                                    closeMenu()
                                }
                                Divider().opacity(0.5)
                                
                                MenuRow(title: "Delete Task", icon: "trash", isDestructive: true) {
                                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                                        withAnimation { tasks.remove(at: idx) }
                                        triggerHaptic(style: .rigid)
                                        saveTasks()
                                        closeMenu()
                                    }
                                }
                            }
                        }
                        .frame(width: 260)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
                        .offset(
                            x: activeMenuFrame.minX,
                            y: opensUpwards ? (activeMenuFrame.minY - 300) : (activeMenuFrame.maxY + 12)
                        )
                        .transition(.scale(scale: 0.8, anchor: opensUpwards ? .bottomLeading : .topLeading).combined(with: .opacity))
                        .zIndex(1)
                    }
                    .ignoresSafeArea()
                    .zIndex(100)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                loadTasks()
                UNUserNotificationCenter.current().requestAuthorization(options: .badge) { _, _ in }
            }
            .sheet(isPresented: $showingAddTask, onDismiss: {
                saveTasks()
            }) {
                AddTaskView(tasks: $tasks, initialImportant: newTaskIsImportant)
            }
            .sheet(item: $taskToEdit, onDismiss: {
                saveTasks()
            }) { task in
                EditTaskView(tasks: $tasks, taskToEdit: task)
            }
            .sheet(isPresented: $showingCompletedTasks, onDismiss: {
                saveTasks()
            }) {
                CompletedTasksView(tasks: $tasks)
            }
        }
    }
    
    // MARK: - Actions
    private func closeMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            activeMenuTask = nil
        }
    }
    
    private func toggleTask(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            let isNowComplete = !tasks[index].isCompleted
            tasks[index].isCompleted = isNowComplete
            tasks[index].completedDate = isNowComplete ? Date() : nil
        }
        triggerHaptic(style: .light)
        saveTasks()
    }
    
    private func toggleImportant(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            if tasks[index].color == .red || tasks[index].isImportant {
                tasks[index].color = .standard
                tasks[index].isImportant = false
            } else {
                tasks[index].color = .red
                tasks[index].isImportant = true
            }
        }
        triggerHaptic(style: .medium)
        saveTasks()
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let taskToDelete = currentTasks[index]
                if let originalIndex = tasks.firstIndex(where: { $0.id == taskToDelete.id }) {
                    tasks.remove(at: originalIndex)
                }
            }
        }
        triggerHaptic(style: .rigid)
        saveTasks()
    }
    
    private func duplicateTask(_ task: Task) {
        let duplicatedTask = Task(title: task.title, isCompleted: false, date: task.date, isImportant: task.isImportant, color: task.color ?? .standard)
        withAnimation(.spring()) {
            tasks.append(duplicatedTask)
        }
        triggerHaptic(style: .light)
        saveTasks()
    }
    
    private func pasteTaskFromClipboard() {
        if let clipboardString = UIPasteboard.general.string, !clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = clipboardString.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            withAnimation(.spring()) {
                for line in lines {
                    let assignedDate = selectedPage == .today ? Date() : Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                    let newTask = Task(title: line, isCompleted: false, date: assignedDate, isImportant: false, color: .standard)
                    tasks.append(newTask)
                }
            }
            triggerHaptic(style: .medium)
            saveTasks()
        }
    }
    
    private func shareTask(_ task: Task) {
        let activityVC = UIActivityViewController(activityItems: [task.title], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Data Saving & Loading
    private func saveTasks() {
        if let encodedData = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encodedData, forKey: saveKey)
        }
        updateAppBadge()
    }
    
    private func loadTasks() {
        if let savedData = UserDefaults.standard.data(forKey: saveKey),
           let decodedTasks = try? JSONDecoder().decode([Task].self, from: savedData) {
            tasks = decodedTasks
        } else {
            tasks = [
                Task(title: "Pack my luggage", isCompleted: false, date: Date(), isImportant: true, color: .red),
                Task(title: "Write blog post", isCompleted: false, date: Date().addingTimeInterval(86400), isImportant: false, color: .blue),
                Task(title: "Film a new video", isCompleted: false, date: Date().addingTimeInterval(172800), isImportant: false, color: .standard)
            ]
        }
        updateAppBadge()
    }
    
    private func updateAppBadge() {
        let incompleteCount = tasks.filter { !$0.isCompleted }.count
        UIApplication.shared.applicationIconBadgeNumber = incompleteCount
    }
}

// MARK: - Extracted Component: Menu Row inside the Glass
struct MenuRow: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            triggerHaptic(style: .light)
            action()
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
            }
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extracted Row View
struct TaskRowView: View {
    let task: Task
    let onTap: () -> Void
    let onLongPress: (CGRect) -> Void
    
    @State private var isPressed = false
    @State private var rowFrame: CGRect = .zero
    
    var displayColor: Color {
        if let tc = task.color, tc != .standard {
            return tc.uiColor
        }
        return task.isImportant ? .red : .primary
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(task.title)
                .font(.system(size: 22, weight: task.isCompleted ? .regular : .bold, design: .default))
                .strikethrough(task.isCompleted, color: .gray)
                .foregroundColor(task.isCompleted ? .gray : displayColor)
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(GeometryReader { geo -> Color in
            DispatchQueue.main.async {
                self.rowFrame = geo.frame(in: .global)
            }
            return Color.clear
        })
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .opacity(isPressed ? 0.6 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.25, perform: {
            triggerHaptic(style: .heavy)
            onLongPress(rowFrame)
        }, onPressingChanged: { pressing in
            isPressed = pressing
        })
    }
}

// MARK: - NEW: Completed Tasks Insights & History Page
struct CompletedTasksView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [Task]
    
    var completedTasks: [Task] {
        tasks.filter { $0.isCompleted }
            .sorted { ($0.completedDate ?? Date.distantPast) > ($1.completedDate ?? Date.distantPast) }
    }
    
    var completedTodayCount: Int {
        completedTasks.filter { Calendar.current.isDateInToday($0.completedDate ?? Date.distantPast) }.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.amoledBackground.ignoresSafeArea()
                
                List {
                    // MARK: INSIGHTS SECTION
                    Section {
                        VStack(spacing: 24) {
                            // Stat Cards
                            HStack(spacing: 16) {
                                StatCard(title: "COMPLETED TODAY", value: "\(completedTodayCount)")
                                StatCard(title: "ALL TIME", value: "\(completedTasks.count)")
                            }
                            
                            // Color Distribution Chart
                            if !completedTasks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("COLOR TAG DISTRIBUTION")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.gray)
                                    
                                    GeometryReader { geo in
                                        HStack(spacing: 0) {
                                            ForEach(TaskColor.allCases, id: \.self) { color in
                                                let count = completedTasks.filter { ($0.color ?? .standard) == color }.count
                                                if count > 0 {
                                                    Rectangle()
                                                        .fill(color == .standard ? Color.gray.opacity(0.3) : color.uiColor)
                                                        .frame(width: max(0, geo.size.width * CGFloat(count) / CGFloat(completedTasks.count)))
                                                }
                                            }
                                        }
                                        .cornerRadius(8)
                                    }
                                    .frame(height: 12)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 24, bottom: 24, trailing: 24))
                    
                    // MARK: HISTORY SECTION
                    if !completedTasks.isEmpty {
                        Section {
                            ForEach(completedTasks) { task in
                                HStack {
                                    Text(task.title)
                                        .font(.system(size: 20, weight: .semibold))
                                        .strikethrough(true, color: .gray.opacity(0.6))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if let cDate = task.completedDate {
                                        Text(cDate.formatted(.dateTime.month().day()))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                }
                                .padding(.vertical, 6)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                                            withAnimation { tasks.remove(at: idx) }
                                            triggerHaptic(style: .rigid)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.3))
                            Text("No completed tasks yet.")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .destructiveAction) {
                    if !completedTasks.isEmpty {
                        Button("Clear All") {
                            withAnimation { tasks.removeAll(where: { $0.isCompleted }) }
                            triggerHaptic(style: .rigid)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// Extracted UI Component for Insights
struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}


// MARK: - Minimal Add Task Sheet
struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [Task]
    var initialImportant: Bool
    
    @State private var title = ""
    @State private var date = Date()
    @State private var selectedColor: TaskColor = .standard
    
    var body: some View {
        ZStack {
            Color.amoledBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                
                HStack {
                    Button("Cancel") { dismiss() }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button("Add Task") {
                        let newTask = Task(title: title, isCompleted: false, date: date, isImportant: selectedColor == .red, color: selectedColor)
                        withAnimation { tasks.append(newTask) }
                        triggerHaptic(style: .medium)
                        dismiss()
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.4) : .primary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 24)
                
                TextField("What needs to be done?", text: $title, axis: .vertical)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("DUE DATE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(1.05, anchor: .leading)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("COLOR TAG")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 24) {
                        ForEach(TaskColor.allCases, id: \.self) { colorOption in
                            Circle()
                                .fill(colorOption == .standard ? Color.gray.opacity(0.2) : colorOption.uiColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == colorOption ? 2 : 0)
                                        .frame(width: 42, height: 42)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { selectedColor = colorOption }
                                    triggerHaptic(style: .light)
                                }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            self.selectedColor = initialImportant ? .red : .standard
        }
    }
}

// MARK: - Minimal Edit Task Sheet
struct EditTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [Task]
    let taskToEdit: Task
    
    @State private var title = ""
    @State private var date = Date()
    @State private var selectedColor: TaskColor = .standard
    
    var body: some View {
        ZStack {
            Color.amoledBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                
                HStack {
                    Button("Cancel") { dismiss() }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button("Save") {
                        if let index = tasks.firstIndex(where: { $0.id == taskToEdit.id }) {
                            tasks[index].title = title
                            tasks[index].date = date
                            tasks[index].color = selectedColor
                            tasks[index].isImportant = (selectedColor == .red)
                        }
                        triggerHaptic(style: .medium)
                        dismiss()
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.4) : .primary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 24)
                
                TextField("Task Title", text: $title, axis: .vertical)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("DUE DATE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .scaleEffect(1.05, anchor: .leading)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("COLOR TAG")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 24) {
                        ForEach(TaskColor.allCases, id: \.self) { colorOption in
                            Circle()
                                .fill(colorOption == .standard ? Color.gray.opacity(0.2) : colorOption.uiColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == colorOption ? 2 : 0)
                                        .frame(width: 42, height: 42)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { selectedColor = colorOption }
                                    triggerHaptic(style: .light)
                                }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            self.title = taskToEdit.title
            self.date = taskToEdit.date
            self.selectedColor = taskToEdit.color ?? (taskToEdit.isImportant ? .red : .standard)
        }
    }
}

#Preview {
    SplashView()
}
