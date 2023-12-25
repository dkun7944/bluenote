//
//  ProjectsTableViewController.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 11/25/21.
//

import UIKit
import UniformTypeIdentifiers
import PhotosUI
import MobileCoreServices
import StoreKit

class ProjectsTableViewController: UITableViewController {

    // MARK: - Variables

    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var projects: [Project] = []

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.sectionFooterHeight = 20
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if projects.count >= 2, 
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    private func reloadData() {
        projects = Cache.projects.getAllItems().sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
        setEmptyStateView()
        tableView.reloadData()
    }

    private func setEmptyStateView() {
        UIView.transition(with: tableView, duration: 0.3) {
            self.tableView.backgroundView = self.projects.isEmpty ? ProjectsEmptyStateView() : nil
        }
    }

    // MARK: - Actions

    @IBAction func addTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.barButtonItem = sender

        alert.addAction(UIAlertAction(title: "Choose File", style: .default, handler: { (_) in
            self.showFilePicker()
        }))

        alert.addAction(UIAlertAction(title: "Choose Video", style: .default, handler: { (_) in
            self.showVideoPicker()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    private func showFilePicker() {
        let filetypes = [UTType("public.audio")!]
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: filetypes, asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.shouldShowFileExtensions = true
        present(documentPicker, animated: true, completion: nil)
    }

    private func showVideoPicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoExportPreset = AVAssetExportPresetPassthrough
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    private func addProject(withAudioURL audioURL: URL, videoURL: URL?) {
        let asset = AVAsset(url: audioURL)

        let project = Project()
        project.name = (videoURL ?? audioURL).deletingPathExtension().lastPathComponent
        project.mediaType = (videoURL == nil) ? .audio : .video
        project.audioFilename = audioURL.lastPathComponent
        project.videoFilename = videoURL?.lastPathComponent
        project.mediaDuration = asset.duration.seconds
        project.needsRename = true

        Cache.projects.cacheItem(project)
        reloadData()
        performSegue(withIdentifier: "projectsToTranscribe", sender: project)
        feedbackGenerator.impactOccurred()
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, 
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: ProjectsTableViewCell.reuseId,
                                                    for: indexPath) as? ProjectsTableViewCell {
            cell.setProject(projects[indexPath.section])
            return cell
        }

        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, 
                            didSelectRowAt indexPath: IndexPath) {
        let project = projects[indexPath.section]
        performSegue(withIdentifier: "projectsToTranscribe", sender: project)
        feedbackGenerator.impactOccurred()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return projects.count
    }

    override func tableView(_ tableView: UITableView, 
                            numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, 
                            viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    override func tableView(_ tableView: UITableView, 
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (action, view, completionHandler) in
            Cache.projects.deleteItem(self.projects[indexPath.row])
            self.projects = Cache.projects.getAllItems().sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
            self.setEmptyStateView()
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
            completionHandler(true)
        }

        deleteAction.backgroundColor = self.view.backgroundColor
        deleteAction.image = UIImage(named: "glyph_minus")

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        return configuration
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "projectsToTranscribe",
           let transcribeVC = segue.destination as? TranscribeViewController,
           let project = sender as? Project {
            transcribeVC.project = project
        }
    }
}

// MARK: - Picker Delegates

extension ProjectsTableViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)

        if let url = info[.mediaURL] as? URL {
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let documentDirectoryUrl = URL(fileURLWithPath: documentDirectory)
            let destinationUrl = documentDirectoryUrl.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: destinationUrl)

            let asset = AVAsset(url: destinationUrl)
            let audioTrackName = UUID().uuidString + ".m4a"
            let audioTrackUrl = documentDirectoryUrl.appendingPathComponent(audioTrackName)
            asset.writeAudioTrack(to: audioTrackUrl) {
                DispatchQueue.main.async {
                    self.addProject(withAudioURL: audioTrackUrl, videoURL: destinationUrl)
                }
            } failure: { error in
                print(error.localizedDescription)
            }
        }

        if let url = info[.imageURL] as? URL {
            try? FileManager.default.removeItem(at: url)
        } else if let url = info[.mediaURL] as? URL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ProjectsTableViewController: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        let fileManager = FileManager.default
        let sourceURL = urls[0]
        let destinationURL = FileManager.getDocumentsDirectory().appendingPathComponent(urls[0].lastPathComponent)

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            print(error)
        }

        self.addProject(withAudioURL: destinationURL, videoURL: nil)
    }
}
