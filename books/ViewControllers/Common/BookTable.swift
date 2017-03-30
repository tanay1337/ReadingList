//
//  BookTableViewController.swift
//  books
//
//  Created by Andrew Bennet on 09/11/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import UIKit
import DZNEmptyDataSet
import CoreData
import CoreSpotlight

class BookTableViewCell: UITableViewCell, ConfigurableCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorsLabel: UILabel!
    @IBOutlet weak var bookCover: UIImageView!
    @IBOutlet weak var readTimeLabel: UILabel!
    
    typealias ResultType = Book
    
    func configureFrom(_ book: BookMetadata) {
        titleLabel.text = book.title
        authorsLabel.text = book.authorList
        bookCover.image = UIImage(optionalData: book.coverImage)
    }
    
    func configureFrom(_ book: Book) {
        titleLabel.text = book.title
        authorsLabel.text = book.authorList
        bookCover.image = UIImage(optionalData: book.coverImage) ?? #imageLiteral(resourceName: "CoverPlaceholder")
        if book.readState == .reading {
            readTimeLabel.text = book.startedReading!.toShortPrettyString()
        }
        else if book.readState == .finished {
            readTimeLabel.text = book.finishedReading!.toShortPrettyString()
        }
        else {
            readTimeLabel.text = nil
        }
    }
}

class BookTable: AutoUpdatingTableViewController {
    var resultsController: NSFetchedResultsController<Book>!
    var resultsFilterer: FetchedResultsFilterer<Book, BookPredicateBuilder>!
    var readStates: [BookReadState]!
    var navBarChangedDelegate: NavBarChangedDelegate!
    var searchController: UISearchController!
    var addButton: UIBarButtonItem!
    
    /// Whether there are any books in this screen. Does not consider the impact of searching - there
    /// may be no results on screen due to a search, but this property might still be true.
    var anyBooksExist = true
    
    override func viewDidLoad() {
        let readStatePredicate = NSPredicate.Or(readStates.map{BookPredicate.readState(equalTo: $0)})
        
        // Set up the results controller
        resultsController = appDelegate.booksStore.fetchedResultsController(readStatePredicate, initialSortDescriptors: BooksStore.standardSortOrder)
    
        // Assign the table updator, which will deal with changes to the data
        tableUpdater = TableUpdater<Book, BookTableViewCell>(table: tableView, controller: resultsController)
        
        /// The UISearchController to which this UITableViewController will be connected.
        searchController = UISearchController(searchResultsController: nil)
        let predicateBuilder = BookPredicateBuilder(readStatePredicate: readStatePredicate)
        resultsFilterer = FetchedResultsFilterer(uiSearchController: searchController, tableView: self.tableView, fetchedResultsController: resultsController, predicateBuilder: predicateBuilder)
        
        // Search Controller UI decisions
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.returnKeyType = .done
        searchController.searchBar.placeholder = "Your Library"
        searchController.hidesNavigationBarDuringPresentation = false
        tableView.tableHeaderView = searchController.searchBar
        
        // Initialise the add button
        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addWasPressed))
        
        // contentOffset will not change before the main run loop ends without queueing it, for splitable devices (iPhone Plus & iPad)
        DispatchQueue.main.async {
            self.tableView.contentOffset.y = self.searchController.searchBar.frame.size.height
        }
        
        // We will manage the clearing of selections ourselves.
        clearsSelectionOnViewWillAppear = false
        
        // Setting the table footer removes the cell separators.
        tableView.tableFooterView = UIView()
        
        // Set the DZN data set source
        tableView.emptyDataSetSource = self

        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Deselect selected rows, so they don't stay highlighted
        if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        
        super.viewDidAppear(animated)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        let numberOfSections = super.numberOfSections(in: tableView)
        
        // Remember whether we have any books
        if !resultsFilterer.showingSearchResults {
            let currentlyAnyBooks = numberOfSections != 0
            if currentlyAnyBooks != anyBooksExist {
                anyBooksExist = currentlyAnyBooks
                searchController.searchBar.isHidden = !anyBooksExist
                // If we hide the search bar, we should make sure the keyboard is gone too.
                // This can happen in slightly tenious circumstances - if a user deletes or removes
                // the last book on the screen whilst in a search mode, then dismisses the search, 
                // brings it back, and then dismisses it again.
                if searchController.searchBar.isHidden {
                    DispatchQueue.main.async {
                        self.searchController.searchBar.resignFirstResponder()
                    }
                }
                navBarChangedDelegate?.navBarChanged()
            }
        }

        return numberOfSections
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Turn the section name into a BookReadState and use its description property
        let sectionAsInt = Int32(self.resultsController.sections![section].name)!
        return BookReadState(rawValue: sectionAsInt)!.description
    }
    
    func triggerBookSelection(_ book: Book){
        // There must be a row corresponding to this book
        guard let indexPathOfSelectedBook = self.resultsController.indexPath(forObject: book) else { return }
            
        // Dismiss the search if there is one
        resultsFilterer.dismissSearch()
        
        // Scroll to and select the row
        self.tableView.scrollToRow(at: indexPathOfSelectedBook, at: .none, animated: false)
        self.tableView.selectRow(at: indexPathOfSelectedBook, animated: false, scrollPosition: .none)
        
        // If there is a detail view presented, pop back to the tabbed page.
        if appDelegate.splitViewController.detailIsPresented {
            appDelegate.splitViewController.bookDetailsViewController?.viewModel = BookDetailsViewModel(book: book)
        }
        else{
            // Segue to the details view, with the cell corresponding to the book as the sender
            self.performSegue(withIdentifier: "showDetail", sender: tableView.cellForRow(at: indexPathOfSelectedBook))
        }
        
        // Get rid of any modal controllers (e.g. edit views, etc)
        self.presentedViewController?.dismiss(animated: false, completion: nil)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // No clicking on books in edit mode, even if you force-press
        return !tableView.isEditing
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let detailsViewController = (segue.destination as? UINavigationController)?.topViewController as? BookDetails,
            let cell = sender as? UITableViewCell,
            let selectedIndex = self.tableView.indexPath(for: cell) {
         
            detailsViewController.viewModel = BookDetailsViewModel(book: self.resultsController.object(at: selectedIndex))
        }
    }

    func addWasPressed() {
        func segueAction(title: String, identifier: String) -> UIAlertAction {
            return UIAlertAction(title: title, style: .default){_ in
                self.parent!.performSegue(withIdentifier: identifier, sender: self)
            }
        }
        
        let optionsAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        optionsAlert.addAction(segueAction(title: "Scan Barcode", identifier: "scanBarcode"))
        optionsAlert.addAction(segueAction(title: "Search Online", identifier: "searchByText"))
        optionsAlert.addAction(segueAction(title: "Enter Manually", identifier: "addManually"))
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // For iPad, set the popover presentation controller's source
        if let popPresenter = optionsAlert.popoverPresentationController {
            popPresenter.barButtonItem = addButton
        }
        
        self.present(optionsAlert, animated: true, completion: nil)
    }
    
    /// Returns the row actions to be used for a book in a given state
    func rowActionsForBookInState(_ readState: BookReadState) -> [UITableViewRowAction] {
        
        func getBookFromIndexPath(rowAction: UITableViewRowAction, indexPath: IndexPath) -> Book {
            return self.resultsController.object(at: indexPath)
        }
        
        // Start with the delete action
        var rowActions = [Book.deleteAction.toUITableViewRowAction(getActionableObject: getBookFromIndexPath)]
        
        // Add the other state change actions where appropriate
        if readState == .toRead {
            rowActions.append(Book.transistionToReadingStateAction.toUITableViewRowAction(getActionableObject: getBookFromIndexPath))
        }
        else if readState == .reading {
            rowActions.append(Book.transistionToFinishedStateAction.toUITableViewRowAction(getActionableObject: getBookFromIndexPath))
        }
        
        return rowActions
    }
}

/// DZNEmptyDataSetSource functions
extension BookTable : DZNEmptyDataSetSource {
    
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        return #imageLiteral(resourceName: "IconOnWhite")
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let titleText: String!
        if resultsFilterer.showingSearchResults {
            titleText = "No Results"
        }
        else if readStates.contains(.reading) {
            titleText = "Reading"
        }
        else {
            titleText = "Finished"
        }
        
        return NSAttributedString(string: titleText, attributes: [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.title1)])
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let descriptionText: String
        if resultsFilterer.showingSearchResults {
            descriptionText = "Try changing your search, or add a new book by tapping the + button above."
        }
        else if readStates.contains(.reading) {
            descriptionText = "There are no books in your reading list.\nAdd a book by tapping the + button above."
        }
        else {
            descriptionText = "There are no books in your finished list.\nAdd a book by tapping the + button above."
        }
        
        return NSAttributedString(string: descriptionText, attributes: [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)])
    }
}