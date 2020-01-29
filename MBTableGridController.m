/*
 Copyright (c) 2008 Matthew Ball - http://www.mattballdesign.com
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MBTableGridController.h"
#import "MBTableGridCell.h"
#import "MBFooterTextCell.h"

NSString* kAutosavedColumnWidthKey = @"AutosavedColumnWidth";
NSString* kAutosavedColumnIndexKey = @"AutosavedColumnIndex";
NSString* kAutosavedColumnHiddenKey = @"AutosavedColumnHidden";

NSString * const PasteboardTypeColumnClass = @"pasteboardTypeColumnClass";

@interface NSMutableArray (SwappingAdditions)
- (void)moveObjectsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)index;
@end

@interface MBTableGridController()
@property (nonatomic, strong) MBTableGridCell *textCell;
@property (nonatomic, strong) MBFooterTextCell *footerTextCell;
@property (nonatomic, strong) NSDictionary *columnWidths;
@property (nonatomic, strong) NSMutableArray *columnIdentifiers;
@end

@implementation MBTableGridController

- (void)awakeFromNib 
{
    
    
    columnSampleWidths = @[@40, @50, @60, @70, @80, @90, @100, @110, @120, @130];

	NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
	NSString *gridComponentID = [infoDict objectForKey:@"GridComponentID"];

	tableGrid.autosaveName = [NSString stringWithFormat:@"MBTableGrid Columns records-table-%@", gridComponentID];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	self.columnWidths = [defaults objectForKey:tableGrid.autosaveName];

	NSNumberFormatter *decimalFormatter = [[NSNumberFormatter alloc] init];
	decimalFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
	decimalFormatter.lenient = YES;
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.dateStyle = NSDateFormatterShortStyle;
	dateFormatter.timeStyle = NSDateFormatterNoStyle;

	// Add 10 columns & rows
    [self tableGrid:tableGrid addColumns:10 shouldReload:NO];
    [self tableGrid:tableGrid addRows:10 shouldReload:NO];
    
    tableGrid.contentInsets = NSEdgeInsetsMake(0, 0, self.controls_view.frame.size.height, 0);
	
	[tableGrid reloadData];
	
	// Register to receive text strings
	[tableGrid registerForDraggedTypes:@[NSStringPboardType]];
	
	self.textCell = [[MBTableGridCell alloc] initTextCell:@""];

	self.footerTextCell = [[MBFooterTextCell alloc] initTextCell:@""];
}

-(NSString *) genRandStringLength: (int) len
{
    
    // Create alphanumeric table
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    // Create mutable string
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    // Add random character to string
    for (int i=0; i<len; i++) {
        
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
        
    }
    
    // return string
    return randomString;
}

#pragma mark Actions

- (IBAction)toggleColumnHeaderVisible:(NSButton *)sender {
    tableGrid.columnHeaderVisible = !tableGrid.isColumnHeaderVisible;
}

- (IBAction)toggleRowHeaderVisible:(NSButton *)sender {
    tableGrid.rowHeaderVisible = !tableGrid.isRowHeaderVisible;
}

- (IBAction)toggleColumnFooterVisible:(NSButton *)sender {
    tableGrid.columnFooterVisible = !tableGrid.isColumnFooterVisible;
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark MBTableGridDataSource

- (NSUInteger)numberOfRowsInTableGrid:(MBTableGrid *)aTableGrid
{
    
	return 1000;
}


- (NSUInteger)numberOfColumnsInTableGrid:(MBTableGrid *)aTableGrid
{
	return 10;
}

- (NSIndexSet *)sortableColumnIndexesInTableGrid:(MBTableGrid *)aTableGrid {
    NSMutableIndexSet *sortableColumns = [NSMutableIndexSet indexSet];
    [sortableColumns addIndex:1];
    [sortableColumns addIndex:3];
    return sortableColumns;
}

- (NSString *)tableGrid:(MBTableGrid *)aTableGrid headerStringForColumn:(NSUInteger)columnIndex {
	return [NSString stringWithFormat:@"Column %lu", columnIndex];
}

- (id)tableGrid:(MBTableGrid *)aTableGrid objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex
{
	return [NSString stringWithFormat:@"%lu %lu", columnIndex, (unsigned long)rowIndex];
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid shouldEditColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	return YES;
}

- (NSCell *)tableGrid:(MBTableGrid *)aTableGrid cellForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	NSCell* cell = self.textCell;
	cell.objectValue = [self tableGrid:aTableGrid objectValueForColumn:columnIndex row:rowIndex];
	return cell;
}

- (void)tableGrid:(MBTableGrid *)aTableGrid setObjectValue:(id)anObject forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if (columnIndex >= [columns count]) {
		return;
	}	
	
	NSMutableArray *column = columns[columnIndex];
	
	if (rowIndex >= [column count]) {
		return;
	}
	
	if (anObject == nil) {
		anObject = @"";
	}
	
	column[rowIndex] = anObject;
	
//	NSLog(@"col: %lu, row: %lu, obj: %@", columnIndex, rowIndex, anObject);

}


- (float)tableGrid:(MBTableGrid *)aTableGrid setWidthForColumn:(NSUInteger)columnIndex {
    
//    return (columnIndex < columnSampleWidths.count) ? [columnSampleWidths[columnIndex] floatValue] : 60;
	
	CGFloat width = 80;
	
	NSString *columnName = [NSString stringWithFormat:@"C-%lu", (long)columnIndex];
	NSDictionary *columnProperty = self.columnWidths[columnName];
	
	if (columnProperty) {
		width =  [columnProperty[kAutosavedColumnWidthKey] floatValue];
	}
	
	return width;
	
}

#pragma mark Footer

- (NSString *)footerDefaultsKeyForColumn:(NSUInteger)columnIndex;
{
    return [NSString stringWithFormat:@"TableGrid-Footer-%ld", columnIndex];
}

- (NSCell *)tableGrid:(MBTableGrid *)aTableGrid footerCellForColumn:(NSUInteger)columnIndex;
{
	return self.footerTextCell;
}

- (id)tableGrid:(MBTableGrid *)aTableGrid footerValueForColumn:(NSUInteger)columnIndex;
{
	return [NSString stringWithFormat:@"Footer %lu", columnIndex];
}

#pragma mark Dragging

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid writeColumnsWithIndexes:(NSIndexSet *)columnIndexes toPasteboard:(NSPasteboard *)pboard
{
	return YES;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid canMoveColumns:(NSIndexSet *)columnIndexes toIndex:(NSUInteger)index
{
	// Allow any column movement
	return YES;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid moveColumns:(NSIndexSet *)columnIndexes toIndex:(NSUInteger)index
{
	[columns moveObjectsAtIndexes:columnIndexes toIndex:index];
    [self.columnIdentifiers moveObjectsAtIndexes:columnIndexes toIndex:index];
	return YES;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	return YES;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid canMoveRows:(NSIndexSet *)rowIndexes toIndex:(NSUInteger)index
{
	// Allow any row movement
	return YES;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid moveRows:(NSIndexSet *)rowIndexes toIndex:(NSUInteger)index
{
	for (NSMutableArray *column in columns) {
		[column moveObjectsAtIndexes:rowIndexes toIndex:index];
	}
	return YES;
}

- (NSDragOperation)tableGrid:(MBTableGrid *)aTableGrid validateDrop:(id <NSDraggingInfo>)info proposedColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex
{
	return NSDragOperationCopy;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid acceptDrop:(id <NSDraggingInfo>)info column:(NSUInteger)columnIndex row:(NSUInteger)rowIndex
{
	NSPasteboard *pboard = [info draggingPasteboard];
	
	NSString *value = [pboard stringForType:NSStringPboardType];
	[self tableGrid:aTableGrid setObjectValue:value forColumn:columnIndex row:rowIndex];
	
	return YES;
}

#pragma mark Copy & Paste

- (void)tableGrid:(MBTableGrid *)aTableGrid copyCellsAtColumns:(NSIndexSet *)columnIndexes rows:(NSIndexSet *)rowIndexes
{
    NSMutableArray *colClasses = [NSMutableArray arrayWithCapacity:columnIndexes.count];
    
    [columnIndexes enumerateIndexesUsingBlock:^(NSUInteger columnIndex, BOOL *stop) {
		[colClasses addObject:[[self tableGrid:aTableGrid cellForColumn:columnIndex row: 0] className]];
    }];
    
	NSMutableArray *rowData = [NSMutableArray arrayWithCapacity:rowIndexes.count];
	
	[rowIndexes enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL *stop) {
		
		NSMutableArray *colData = [NSMutableArray arrayWithCapacity:columnIndexes.count];
        
		[columnIndexes enumerateIndexesUsingBlock:^(NSUInteger columnIndex, BOOL *stop) {
			
			NSArray *row = columns[columnIndex];
			id cellData = row[rowIndex];
			[colData addObject:cellData];
			
		}];
		
		NSString *rowString = [colData componentsJoinedByString:@"\t"];
		
		[rowData addObject:rowString];
		
	}];
	
	NSString *tsvString = [rowData componentsJoinedByString:@"\n"];
	
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	
	[pasteboard clearContents];

	[pasteboard declareTypes:@[NSPasteboardTypeTabularText, NSPasteboardTypeString, PasteboardTypeColumnClass] owner:nil];
	[pasteboard setString:tsvString forType:NSPasteboardTypeTabularText];
	[pasteboard setString:tsvString forType:NSPasteboardTypeString];
    [pasteboard setPropertyList:colClasses forType:PasteboardTypeColumnClass];

}

- (void)tableGrid:(MBTableGrid *)aTableGrid pasteCellsAtColumns:(NSIndexSet *)columnIndexes rows:(NSIndexSet *)rowIndexes
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    BOOL isSingleSelection = columnIndexes.count == 1 && rowIndexes.count == 1;
    NSString *tavString = [pasteboard stringForType:NSPasteboardTypeTabularText];
    
    if (!tavString.length) {
        tavString = [pasteboard stringForType:NSPasteboardTypeString];
    }
    
    if (!tavString.length) {
        return;
    }
    
    // Extract the rows and columns to a more convenient form
    NSMutableArray *rowArray = [NSMutableArray array];
    
    for (NSString *rowString in [tavString componentsSeparatedByString:@"\n"]) {
        
        NSMutableArray *columnArray = [NSMutableArray array];
        
        for (NSString *columnString in [rowString componentsSeparatedByString:@"\t"]) {
            
            [columnArray addObject:columnString];
        }
        
        [rowArray addObject:columnArray];
    }
    
    NSUInteger firstSelectedColumn = [columnIndexes firstIndex];
    NSUInteger firstSelectedRow = [rowIndexes firstIndex];
    NSUInteger numberOfExistingColumns = [columns count];
    NSUInteger numberOfExistingRows = [[columns firstObject] count];
    NSUInteger numberOfPastingColumns = [[rowArray firstObject] count];
    NSUInteger numberOfPastingRows = [rowArray count];
    
    // If pasting to a single cell, we want to paste all of the values, so add rows and columns if needed
    if (isSingleSelection) {
        NSInteger extraColumns = firstSelectedColumn + numberOfPastingColumns - numberOfExistingColumns;
        NSInteger extraRows = firstSelectedRow + numberOfPastingRows - numberOfExistingRows;
        
        if (extraColumns > 0) {
            // Add extra columns; a real controller could use the PasteboardTypeColumnClass values to add appropriate column types to the database
            [self tableGrid:aTableGrid addColumns:extraColumns shouldReload:NO];
        }
        
        if (extraRows > 0) {
            [self tableGrid:aTableGrid addRows:extraRows shouldReload:NO];
        }
    } else {
        numberOfPastingColumns = columnIndexes.count;
        numberOfPastingRows = rowIndexes.count;
    }
    
    // Insert the values
    [rowArray enumerateObjectsUsingBlock:^(NSArray *columnArray, NSUInteger rowOffset, BOOL *stopRows) {
        [columnArray enumerateObjectsUsingBlock:^(NSString *value, NSUInteger columnOffset, BOOL *stopColumns) {
            
            NSUInteger column = firstSelectedColumn + columnOffset;
            NSUInteger row = firstSelectedRow + rowOffset;

			[self tableGrid:aTableGrid setObjectValue:value forColumn:column row:row];
            
            if (columnOffset == numberOfPastingColumns - 1) {
                *stopColumns = YES;
            }
        }];
        
        if (rowOffset == numberOfPastingRows - 1) {
            *stopRows = YES;
        }
    }];
}

#pragma mark Adding and Removing Columns & Rows

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid addColumns:(NSUInteger)numberOfColumns shouldReload:(BOOL)shouldReload;
{
    // Default number of rows
    NSUInteger numberOfRows = 0;
    
    // If there are already other columns, get the number of rows from one of them
    if ([columns count] > 0) {
        numberOfRows = [columns[0] count];
    }
    
    for (NSUInteger column = 0; column < numberOfColumns; column++) {
        
        NSMutableArray *newColumn = [NSMutableArray array];
        
        for (NSUInteger row = 0; row < numberOfRows; row++) {
            // Insert blank items for each row
            [newColumn addObject:@""];
        }
        
        [columns addObject:newColumn];
        
        if (columns.count > self.columnIdentifiers.count) {
            [self.columnIdentifiers addObject:[NSString stringWithFormat:@"extra%@", @(columns.count)]];
        }
    }
    
    if (shouldReload) {
        [tableGrid reloadData];
    }
    
    return YES;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid addRows:(NSUInteger)numberOfRows;
{
    return [self tableGrid:aTableGrid addRows:numberOfRows shouldReload:YES];
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid addRows:(NSUInteger)numberOfRows shouldReload:(BOOL)shouldReload;
{
    for (NSUInteger row = 0; row < numberOfRows; row++) {
        for (NSMutableArray *column in columns) {
            // Add a blank item to each row
            [column addObject:@""];
        }
    }
    
    [aTableGrid.columnRects removeAllObjects];
    
    if (shouldReload) {
        [aTableGrid reloadData];
    }
    
    return YES;
}

- (BOOL)tableGrid:(MBTableGrid *)aTableGrid removeRows:(NSIndexSet *)rowIndexes;
{
    for (NSMutableArray *column in columns) {
        [column removeObjectsAtIndexes:rowIndexes];
    }
    
    [aTableGrid reloadData];
    
    return YES;
}

#pragma mark MBTableGridDelegate

- (void)tableGridDidMoveRows:(NSNotification *)aNotification
{
	NSLog(@"moved");
}

- (void)tableGrid:(MBTableGrid *)aTableGrid userDidEnterInvalidStringInColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex errorDescription:(NSString *)errorDescription {
	NSLog(@"Invalid input at %lu,%lu: %@", (unsigned long)columnIndex, (unsigned long)rowIndex, errorDescription);
}

- (void)tableGrid:(MBTableGrid *)aTableGrid didAddRows:(NSIndexSet *)rowIndexes;
{
    // Add the rows to the database, or whatever is needed
}

#pragma mark - QuickLook

-(void)quickLookAction:(id)sender {
	//	[[NSApp mainWindow] makeFirstResponder:self];
	
	if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]) {
		[[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
	} else {
		QLPreviewPanel *previewPanel = [QLPreviewPanel sharedPreviewPanel];
		previewPanel.dataSource = self;
		previewPanel.delegate = self;
		[previewPanel makeKeyAndOrderFront:sender];
	}
}


// Quick Look panel support

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel; {
	return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
	// This document is now responsible of the preview panel
	// It is allowed to set the delegate, data source and refresh panel.
	
	panel.delegate = self;
	panel.dataSource = self;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
	panel.delegate = nil;
	panel.dataSource = nil;
}

// Quick Look panel data source

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
	return 1;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
	NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
	NSURL *fileURL = nil;
	__block NSURL *returnURL = nil;
	NSError *error = nil;
	fileURL = [[NSBundle mainBundle] URLForImageResource:@"rose"];
	
	[coordinator coordinateReadingItemAtURL:fileURL
									options:NSFileCoordinatorReadingWithoutChanges
									  error:&error
								 byAccessor:^(NSURL *newURL) {
									 returnURL = newURL;
								 }];
	
	return returnURL;
}

// This delegate method provides the rect on screen from which the panel will zoom.
- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item {
	
	// convert selected cell rect to screen coordinates
	NSInteger selectedColumn = [tableGrid.selectedColumnIndexes firstIndex];
	NSInteger selectedRow = [tableGrid.selectedRowIndexes firstIndex];
	NSCell *selectedCell = [tableGrid selectedCell];
	
	NSRect photoPreviewFrame = [tableGrid frameOfCellAtColumn:selectedColumn row:selectedRow];
	NSRect rectInWinCoords = [selectedCell.controlView convertRect:photoPreviewFrame toView:nil];
	NSRect rectInScreenCoords = [[NSApp mainWindow] convertRectToScreen:rectInWinCoords];
	
	return rectInScreenCoords;
}

@end

@implementation NSMutableArray (SwappingAdditions)

- (void)moveObjectsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)index
{
	NSArray *objects = [self objectsAtIndexes:indexes];
	
	// Determine the new indexes for the objects
	NSRange newRange = NSMakeRange(index, [indexes count]);
	if (index > [indexes firstIndex]) {
		newRange.location -= [indexes count];
	}
	NSIndexSet *newIndexes = [NSIndexSet indexSetWithIndexesInRange:newRange];
	
	// Determine where the original objects are
	NSIndexSet *originalIndexes = indexes;
	
	// Remove the objects from their original locations
	[self removeObjectsAtIndexes:originalIndexes];
	
	// Insert the objects at their new location
	[self insertObjects:objects atIndexes:newIndexes];
	
}

@end
