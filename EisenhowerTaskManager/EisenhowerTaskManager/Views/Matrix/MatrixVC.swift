//
//  MatrixVC.swift
//  EisenhowerTaskManager
//
//  Created by Oleg GORBATCHEV on 11/03/2018.
//  Copyright © 2018 Oleg Gorbatchev. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import SwiftDate

class MatrixVC: UIViewController {
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!

    private var isSearchBarEditing = false
    private var databaseHandle: DatabaseHandle?
    private let tasksChild = "users/\(Auth.auth().currentUser?.uid ?? "")/tasks"
    private let titleSections: [String] = TaskCategory.string
    private var completedTasks: [TaskCategory: [Task]] = [
        .dofirst: [Task](),
        .toSchedule: [Task](),
        .toDelegate: [Task](),
        .toNotDo: [Task]()
    ]
    private var incompleteTasks: [TaskCategory: [Task]] = [
        .dofirst: [Task](),
        .toSchedule: [Task](),
        .toDelegate: [Task](),
        .toNotDo: [Task]()
    ]
    private var allTasks: [TaskCategory: [Task]] = [
        .dofirst: [Task](),
        .toSchedule: [Task](),
        .toDelegate: [Task](),
        .toNotDo: [Task]()
    ]
    private var tasks = [Task]() {
        didSet {
            setupTasks()
        }
    }

    deinit {
        if let databaseHandle = databaseHandle {
            Database.database().reference().child(tasksChild).removeObserver(withHandle: databaseHandle)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupSegmentedControl()
        setupTableView()
        setupFirebase()
        checkStates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // This is a bug in iOS 11.2 and happens because the UIBarButtonItem stays highlighted after navigation
        // and does not return to its normal state after the other view controller pops.
        // Check: https://stackoverflow.com/questions/47754472/ios-uinavigationbar-button-remains-faded-after-segue-back
        setupNavigationBar(rightButtonWithTitle: L10n.Generic.add, andAction: #selector(rightButtonAction))
    }

    @IBAction func indexChanged(_ sender: AnyObject) {
        tableView?.reloadData()
    }
}

extension MatrixVC {
    private func setupNavigationBar() {
        title = L10n.Generic.matrix
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    @objc private func updateData() {
        tableView?.reloadData()
    }

    private func checkStates() {
        if States.isForceTouchAddTask {
            States.isForceTouchAddTask = false
            rightButtonAction()
        }
    }

    private func setupSegmentedControl() {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: L10n.Generic.completed, at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: L10n.Generic.incomplete, at: 1, animated: false)
        segmentedControl.insertSegment(withTitle: L10n.Generic.all, at: 2, animated: false)
        segmentedControl.selectedSegmentIndex = 0
    }

    private func setupTableView() {
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.register(
            UINib(nibName: "TaskTableViewCell", bundle: nil),
            forCellReuseIdentifier: "TaskTableViewCell"
        )
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: tableView)
        }
    }

    private func setupFirebase() {
        databaseHandle = Database.database().reference().child(tasksChild)
            .observe(DataEventType.value) { [weak self] snapshot in
                self?.tasks.removeAll()
                snapshot.children.forEach { child in
                    if let dataSnapshot = child as? DataSnapshot {
                        let task = Task(snapshot: dataSnapshot)
                        self?.tasks.append(task)
                    }
                }
                self?.tableView?.reloadData()
        }
    }

    private func setupTasks() {
        allTasks[.dofirst] = tasks.filter { $0.category == TaskCategory.dofirst }
        allTasks[.toSchedule] = tasks.filter { $0.category == TaskCategory.toSchedule }
        allTasks[.toDelegate] = tasks.filter { $0.category == TaskCategory.toDelegate }
        allTasks[.toNotDo] = tasks.filter { $0.category == TaskCategory.toNotDo }
        completedTasks[.dofirst] = allTasks[.dofirst]?.filter { $0.completed == true }
        completedTasks[.toSchedule] = allTasks[.toSchedule]?.filter { $0.completed == true }
        completedTasks[.toDelegate] = allTasks[.toDelegate]?.filter { $0.completed == true }
        completedTasks[.toNotDo] = allTasks[.toNotDo]?.filter { $0.completed == true }
        incompleteTasks[.dofirst] = allTasks[.dofirst]?.filter { $0.completed == false }
        incompleteTasks[.toSchedule] = allTasks[.toSchedule]?.filter { $0.completed == false }
        incompleteTasks[.toDelegate] = allTasks[.toDelegate]?.filter { $0.completed == false }
        incompleteTasks[.toNotDo] = allTasks[.toNotDo]?.filter { $0.completed == false }
    }

    @objc private func rightButtonAction() {
        let addTaskVC = AddTaskVC()
        navigationController?.pushViewController(addTaskVC, animated: true)
    }
}

extension MatrixVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return titleSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let selectedSegmentIndex = segmentedControl?.selectedSegmentIndex,
            let category = TaskCategory(rawValue: section) {
            switch selectedSegmentIndex {
            case 0:
                return completedTasks[category]?.count ?? 0
            case 1:
                return incompleteTasks[category]?.count ?? 0
            case 2:
                return allTasks[category]?.count ?? 0
            default:
                break
            }
        }
        return 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return titleSections[section]
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskTableViewCell") as? TaskTableViewCell
        if let selectedSegmentIndex = segmentedControl?.selectedSegmentIndex,
            let category = TaskCategory(rawValue: indexPath.section) {
            switch selectedSegmentIndex {
            case 0:

                cell?.task = completedTasks[category]?[indexPath.row]
            case 1:
                cell?.task = incompleteTasks[category]?[indexPath.row]
            case 2:
                cell?.task = allTasks[category]?[indexPath.row]
            default:
                break
            }
        }
        return cell ?? UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detailedTaskVC = DetailedTaskVC()
        if let category = TaskCategory(rawValue: indexPath.section) {
            detailedTaskVC.task = allTasks[category]?[indexPath.row]
        }
        navigationController?.pushViewController(detailedTaskVC, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCellEditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let selectedSegmentIndex = segmentedControl?.selectedSegmentIndex,
                let category = TaskCategory(rawValue: indexPath.section) {
                switch selectedSegmentIndex {
                case 0:
                    completedTasks[category]?[indexPath.row].databaseReference?.removeValue()
                case 1:
                    incompleteTasks[category]?[indexPath.row].databaseReference?.removeValue()
                case 2:
                    allTasks[category]?[indexPath.row].databaseReference?.removeValue()
                default:
                    break
                }
            }
        }
    }
}

extension MatrixVC: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                           viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = tableView.indexPathForRow(at: location) else {
            return nil
        }
        let detailedTaskVC = DetailedTaskVC()
        if let category = TaskCategory(rawValue: indexPath.section) {
            detailedTaskVC.task = allTasks[category]?[indexPath.row]
        }
        return detailedTaskVC
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                           commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
}
