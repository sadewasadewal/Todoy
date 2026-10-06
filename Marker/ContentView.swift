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

// MARK: - Sticker Models
struct PlacedSticker: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var stickerName: String
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0 // In degrees
    var zIndex: Double = 1.0
}

struct StickerItem: Identifiable, Hashable {
    let id: String
    let name: String
    let title: String
}

let availableStickers: [StickerItem] = [
    StickerItem(id: "sticker_swift_bird", name: "sticker_swift_bird", title: "Swift"),
    StickerItem(id: "sticker_xcode", name: "sticker_xcode", title: "Xcode"),
    StickerItem(id: "sticker_tim_phil", name: "sticker_tim_phil", title: "Tim & Craig"),
    StickerItem(id: "sticker_freeze_emoji", name: "sticker_freeze_emoji", title: "Freezing"),
    StickerItem(id: "sticker_swift_logo", name: "sticker_swift_logo", title: "Swift Logo"),
    StickerItem(id: "sticker_ferris_crab", name: "sticker_ferris_crab", title: "Ferris"),
    StickerItem(id: "sticker_hello_rainbow", name: "sticker_hello_rainbow", title: "Rainbow Hello"),
    StickerItem(id: "sticker_hello_black", name: "sticker_hello_black", title: "Black Hello"),
    StickerItem(id: "sticker_appstore", name: "sticker_appstore", title: "App Store"),
    StickerItem(id: "sticker_apple_ribbon", name: "sticker_apple_ribbon", title: "Apple Ribbon"),
    StickerItem(id: "sticker_mac_classic", name: "sticker_mac_classic", title: "Classic Mac"),
    StickerItem(id: "sticker_vision_pro", name: "sticker_vision_pro", title: "Vision Pro"),
    StickerItem(id: "sticker_neon_bolt", name: "sticker_neon_bolt", title: "Lightning"),
    StickerItem(id: "sticker_wwdc21", name: "sticker_wwdc21", title: "WWDC 21"),
    StickerItem(id: "sticker_hello_world", name: "sticker_hello_world", title: "Hello World"),
    StickerItem(id: "sticker_blue_star", name: "sticker_blue_star", title: "Sparkle Star")
]

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
    
    // Sticker Studio State
    @State private var placedStickers: [PlacedSticker] = []
    @State private var showingStickerDrawer = false
    @State private var selectedStickerId: UUID? = nil
    @State private var topZIndex: Double = 1.0
    
    // Tray Drag & Paste Tracking
    @State private var draggingStickerFromTray: StickerItem? = nil
    @State private var trayDragLocation: CGPoint = .zero
    @State private var isDraggingFromTray: Bool = false
    
    let saveKey = "SavedTasks"
    let stickersSaveKey = "SavedPlacedStickers"
    
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
            ZStack(alignment: .topLeading) {
                Color.amoledBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedStickerId = nil
                    }
                
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
                    
                    HStack(alignment: .center, spacing: 14) {
                        Spacer()
                        
                        Text(todayString.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                        
                        // Sticker Drawer Button
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showingStickerDrawer.toggle()
                                if showingStickerDrawer {
                                    selectedStickerId = nil
                                }
                            }
                            triggerHaptic(style: .medium)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(showingStickerDrawer ? Color.primary : Color(UIColor.secondarySystemFill))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: showingStickerDrawer ? "sparkles" : "face.smiling.fill")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundColor(showingStickerDrawer ? Color(UIColor.systemBackground) : .primary)
                            }
                            .shadow(color: .primary.opacity(0.12), radius: 5, y: 3)
                        }
                        .accessibilityLabel("Sticker Studio")
                        
                        // Add Task Button
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
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    showingStickerDrawer.toggle()
                                }
                                triggerHaptic(style: .medium)
                            } label: {
                                Label(showingStickerDrawer ? "Close Stickers" : "Sticker Studio", systemImage: "face.smiling")
                            }
                            
                            if !placedStickers.isEmpty {
                                Button(role: .destructive) {
                                    withAnimation(.spring()) {
                                        placedStickers.removeAll()
                                        selectedStickerId = nil
                                    }
                                    triggerHaptic(style: .rigid)
                                    saveStickers()
                                } label: {
                                    Label("Clear Screen Stickers (\(placedStickers.count))", systemImage: "sparkles.slash")
                                }
                            }
                            
                            Divider()
                            
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
                
                // MARK: - PLACED STICKERS INTERACTIVE CANVAS
                ForEach($placedStickers) { $sticker in
                    PlacedStickerView(
                        sticker: $sticker,
                        isSelected: selectedStickerId == sticker.id,
                        onSelect: {
                            selectedStickerId = sticker.id
                            topZIndex += 1.0
                            sticker.zIndex = topZIndex
                            saveStickers()
                        },
                        onDelete: {
                            if let idx = placedStickers.firstIndex(where: { $0.id == sticker.id }) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    placedStickers.remove(at: idx)
                                }
                                selectedStickerId = nil
                                saveStickers()
                            }
                        },
                        onCommit: {
                            saveStickers()
                        }
                    )
                }
                
                // MARK: - LIVE DRAG PREVIEW FROM TRAY
                if isDraggingFromTray, let item = draggingStickerFromTray {
                    Image(item.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .scaleEffect(1.15)
                        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
                        .position(trayDragLocation)
                        .zIndex(999)
                        .allowsHitTesting(false)
                }
                
                // MARK: - STICKER STUDIO BOTTOM DRAWER
                if showingStickerDrawer {
                    VStack {
                        Spacer()
                        StickerDrawerView(
                            isPresented: $showingStickerDrawer,
                            placedStickersCount: placedStickers.count,
                            onSelectSticker: { item in
                                addSticker(item)
                            },
                            onDragStart: { item, loc in
                                isDraggingFromTray = true
                                draggingStickerFromTray = item
                                trayDragLocation = loc
                            },
                            onDragChange: { loc in
                                trayDragLocation = loc
                            },
                            onDragEnd: { loc in
                                if let item = draggingStickerFromTray, loc.y < UIScreen.main.bounds.height - 160 {
                                    addSticker(item, at: loc)
                                }
                                isDraggingFromTray = false
                                draggingStickerFromTray = nil
                            },
                            onClearAllStickers: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    placedStickers.removeAll()
                                    selectedStickerId = nil
                                }
                                triggerHaptic(style: .rigid)
                                saveStickers()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(200)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                loadTasks()
                loadStickers()
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
    
    // MARK: - Sticker Studio Actions
    private func addSticker(_ item: StickerItem, at location: CGPoint? = nil) {
        let screenBounds = UIScreen.main.bounds
        let targetX = location?.x ?? (screenBounds.midX + CGFloat.random(in: -35...35))
        let targetY = location?.y ?? (screenBounds.midY - 40 + CGFloat.random(in: -35...35))
        
        topZIndex += 1.0
        let newSticker = PlacedSticker(
            stickerName: item.name,
            x: targetX,
            y: targetY,
            scale: 1.0,
            rotation: Double.random(in: -6...6),
            zIndex: topZIndex
        )
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            placedStickers.append(newSticker)
            selectedStickerId = newSticker.id
        }
        triggerHaptic(style: .medium)
        saveStickers()
    }
    
    private func saveStickers() {
        if let encodedData = try? JSONEncoder().encode(placedStickers) {
            UserDefaults.standard.set(encodedData, forKey: stickersSaveKey)
        }
    }
    
    private func loadStickers() {
        if let savedData = UserDefaults.standard.data(forKey: stickersSaveKey),
           let decodedStickers = try? JSONDecoder().decode([PlacedSticker].self, from: savedData) {
            placedStickers = decodedStickers
            topZIndex = (decodedStickers.map { $0.zIndex }.max() ?? 1.0) + 1.0
        }
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

// MARK: - Interactive Placed Sticker Component
struct PlacedStickerView: View {
    @Binding var sticker: PlacedSticker
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onCommit: () -> Void
    
    @State private var dragTranslation: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @State private var rotationDelta: Angle = .zero
    
    private let baseSize: CGFloat = 100
    
    var body: some View {
        let currentTotalScale = max(0.35, min(4.0, sticker.scale * pinchScale))
        let currentTotalRotation = Angle.degrees(sticker.rotation) + rotationDelta
        
        ZStack(alignment: .topTrailing) {
            Image(sticker.stickerName)
                .resizable()
                .scaledToFit()
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(currentTotalScale)
                .rotationEffect(currentTotalRotation)
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.35 : 0.18),
                    radius: isSelected ? 10 : 5,
                    x: 0,
                    y: isSelected ? 6 : 3
                )
                .overlay(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .frame(width: baseSize * currentTotalScale + 14, height: baseSize * currentTotalScale + 14)
                                .rotationEffect(currentTotalRotation)
                        }
                    }
                )
            
            // Delete button when selected
            if isSelected {
                Button {
                    triggerHaptic(style: .rigid)
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.red)
                        .background(Circle().fill(Color.white).padding(2))
                        .shadow(radius: 3)
                }
                .offset(x: 10, y: -10)
                .rotationEffect(currentTotalRotation)
            }
        }
        .frame(width: baseSize, height: baseSize)
        .contentShape(Rectangle())
        .offset(
            x: sticker.x - (baseSize / 2) + dragTranslation.width,
            y: sticker.y - (baseSize / 2) + dragTranslation.height
        )
        .zIndex(sticker.zIndex)
        .onTapGesture {
            onSelect()
            triggerHaptic(style: .light)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isSelected {
                        onSelect()
                    }
                    dragTranslation = value.translation
                }
                .onEnded { value in
                    sticker.x += value.translation.width
                    sticker.y += value.translation.height
                    dragTranslation = .zero
                    triggerHaptic(style: .light)
                    onCommit()
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { scale in
                    if !isSelected {
                        onSelect()
                    }
                    pinchScale = scale
                }
                .onEnded { scale in
                    sticker.scale = max(0.35, min(4.0, sticker.scale * scale))
                    pinchScale = 1.0
                    triggerHaptic(style: .light)
                    onCommit()
                }
        )
        .simultaneousGesture(
            RotationGesture()
                .onChanged { angle in
                    if !isSelected {
                        onSelect()
                    }
                    rotationDelta = angle
                }
                .onEnded { angle in
                    sticker.rotation += angle.degrees
                    rotationDelta = .zero
                    triggerHaptic(style: .light)
                    onCommit()
                }
        )
    }
}

// MARK: - Sticker Drawer / Picker View
struct StickerDrawerView: View {
    @Binding var isPresented: Bool
    let placedStickersCount: Int
    let onSelectSticker: (StickerItem) -> Void
    let onDragStart: (StickerItem, CGPoint) -> Void
    let onDragChange: (CGPoint) -> Void
    let onDragEnd: (CGPoint) -> Void
    let onClearAllStickers: () -> Void
    
    private let rows = [
        GridItem(.fixed(78), spacing: 10),
        GridItem(.fixed(78), spacing: 10)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)
            
            // Header Bar
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("STICKER STUDIO")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                    
                    if placedStickersCount > 0 {
                        Text("\(placedStickersCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                if placedStickersCount > 0 {
                    Button {
                        onClearAllStickers()
                    } label: {
                        Text("Clear Screen")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.trailing, 6)
                }
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isPresented = false
                    }
                    triggerHaptic(style: .light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
            
            // Stickers Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, spacing: 12) {
                    ForEach(availableStickers) { item in
                        StickerDrawerCell(
                            item: item,
                            onSelect: {
                                onSelectSticker(item)
                            },
                            onDragStart: { loc in
                                onDragStart(item, loc)
                            },
                            onDragChange: onDragChange,
                            onDragEnd: onDragEnd
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .frame(height: 172)
            
            // Helper guide text
            HStack(spacing: 6) {
                Text("Tap or drag to paste • Pinch to resize • Rotate to tilt")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(
            Color.amoledBackground.opacity(0.88)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: -5)
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 60 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isPresented = false
                        }
                        triggerHaptic(style: .light)
                    }
                }
        )
    }
}

// MARK: - Sticker Drawer Individual Cell
struct StickerDrawerCell: View {
    let item: StickerItem
    let onSelect: () -> Void
    let onDragStart: (CGPoint) -> Void
    let onDragChange: (CGPoint) -> Void
    let onDragEnd: (CGPoint) -> Void
    
    @State private var isPressing = false
    @State private var hasInitiatedDrag = false
    
    var body: some View {
        VStack(spacing: 4) {
            Image(item.name)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            
            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(width: 72, height: 74)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemFill).opacity(0.35))
        )
        .scaleEffect(isPressing ? 0.92 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressing)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    if !hasInitiatedDrag {
                        hasInitiatedDrag = true
                        onDragStart(value.location)
                    } else {
                        onDragChange(value.location)
                    }
                }
                .onEnded { value in
                    if hasInitiatedDrag {
                        onDragEnd(value.location)
                        hasInitiatedDrag = false
                    }
                }
        )
    }
}

#Preview {
    SplashView()
}
