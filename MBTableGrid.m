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

#import "MBTableGrid.h"
#import "MBTableGridHeaderView.h"
#import "MBTableGridFooterView.h"
#import "MBTableGridHeaderCell.h"
#import "MBTableGridContentView.h"
#import "MBTableGridContentScrollView.h"
#import "MBTableGridTextFinderClient.h"
#import "MBTableGridCell.h"
#import "NSScrollView+InsetRectangles.h"

#pragma mark -
#pragma mark Constant Definitions
NSString *MBTableGridDidChangeSelectionNotification     = @"MBTableGridDidChangeSelectionNotification";
NSString *MBTableGridDidMoveColumnsNotification         = @"MBTableGridDidMoveColumnsNotification";
NSString *MBTableGridDidMoveRowsNotification            = @"MBTableGridDidMoveRowsNotification";
CGFloat MBTableHeaderMinimumColumnWidth = 60.0f;
CGFloat MBTableHeaderSortIndicatorWidth = 10.0;
CGFloat MBTableHeaderSortIndicatorMargin = 4.0;

#define MBTableGridColumnHeaderHeight 24.0
#define MBTableGridColumnFooterHeight 24.0
#define MBTableGridRowHeaderWidth 56.0

#pragma mark -
#pragma mark Drag Types
NSString *MBTableGridColumnDataType = @"mbtablegrid.pasteboard.column";
NSString *MBTableGridRowDataType = @"mbtablegrid.pasteboard.row";

@interface MBTableGrid (Drawing)
@end

@interface MBTableGrid (DataAccessors)
- (NSString *)_headerStringForColumn:(NSUInteger)columnIndex;
- (NSString *)_headerStringForRow:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumns:(NSIndexSet *)columnIndexes rows:(NSIndexSet *)rowIndexes;
- (CGFloat)_minimumWidthForColumn:(NSUInteger)columnIndex;
- (CGFloat)_widthForColumn:(NSUInteger)columnIndex;
- (void)_setWidth:(CGFloat) width forColumn:(NSUInteger)columnIndex;
- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (id)_footerValueForColumn:(NSUInteger)columnIndex;
- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex;
@end

@interface MBTableGrid (DragAndDrop)
- (void)_dragColumnsWithEvent:(NSEvent *)theEvent;
- (void)_dragRowsWithEvent:(NSEvent *)theEvent;
- (NSImage *)_imageForSelectedColumns;
- (NSImage *)_imageForSelectedRows;
- (NSUInteger)_dropColumnForPoint:(NSPoint)aPoint;
- (NSUInteger)_dropRowForPoint:(NSPoint)aPoint;
@end

@interface MBTableGrid (PrivateAccessors)
- (MBTableGridContentView *)_contentView;
- (void)_setStickyColumn:(MBHorizontalEdge)stickyColumn row:(MBVerticalEdge)stickyRow;
- (MBHorizontalEdge)_stickyColumn;
- (MBVerticalEdge)_stickyRow;
@end

@interface MBTableGridContentView (Private)
- (void)_setDraggingColumnOrRow:(BOOL)flag;
- (void)_setDropColumn:(NSInteger)columnIndex;
- (void)_setDropRow:(NSInteger)rowIndex;
@end


@implementation NSIndexSet (DirectionalExpansionConvenience)
- (NSUInteger)indexForExpansionInHorizontalDirection:(MBHorizontalEdge)direction
{
    return (direction == MBHorizontalEdgeLeft)
        ? self.firstIndex
        : self.lastIndex;
}

- (NSUInteger)indexForExpansionInVerticalDirection:(MBVerticalEdge)direction
{
    return (direction == MBVerticalEdgeTop)
        ? self.firstIndex
        : self.lastIndex;
}
@end

NS_INLINE MBHorizontalEdge MBOppositeHorizontalEdge(MBHorizontalEdge other) {
    return (other == MBHorizontalEdgeRight) ? MBHorizontalEdgeLeft : MBHorizontalEdgeRight;
}

NS_INLINE MBVerticalEdge MBOppositeVerticalEdge(MBVerticalEdge other) {
    return (other == MBVerticalEdgeTop) ? MBVerticalEdgeBottom : MBVerticalEdgeTop;
}

@interface MBTableGrid ()
@property (nonatomic, readwrite, assign) MBHorizontalEdge previousHorizontalSelectionDirection;
@property (nonatomic, readwrite, assign) MBVerticalEdge previousVerticalSelectionDirection;
@end


@implementation MBTableGrid

@synthesize allowsMultipleSelection;
@synthesize dataSource;
@synthesize delegate;
@synthesize selectedColumnIndexes;
@synthesize selectedRowIndexes;
@synthesize showsGrabHandles;
@synthesize columnFooterView;
@synthesize singleClickCellEdit;
@synthesize previousHorizontalSelectionDirection;
@synthesize previousVerticalSelectionDirection;

#pragma mark -
#pragma mark Initialization & Superclass Overrides

+ (BOOL)requiresConstraintBasedLayout { return YES; }

- (id)initWithFrame:(NSRect)frameRect {
	if (self = [super initWithFrame:frameRect]) {
		_columnWidths = [NSMutableDictionary dictionary];

		// Post frame changed notifications
		self.postsFrameChangedNotifications = YES;

		// Set the default cell
		MBTableGridCell *defaultCell = [[MBTableGridCell alloc] initTextCell:@""];
		defaultCell.bordered = YES;
		defaultCell.scrollable = YES;
		defaultCell.lineBreakMode = NSLineBreakByTruncatingTail;
		self.cell = defaultCell;
        
        // Setup the content view
        NSRect contentFrame = NSMakeRect(0, 0,
                                         self.frame.size.width,
                                         self.frame.size.height);
        contentScrollView = [[MBTableGridContentScrollView alloc] initWithFrame:contentFrame];
        contentView = [[MBTableGridContentView alloc] initWithFrame:NSMakeRect(0, 0, contentFrame.size.width, contentFrame.size.height)
                                                       andTableGrid:self];
        contentScrollView.documentView = contentView;
        contentScrollView.hasHorizontalScroller = YES;
        contentScrollView.hasVerticalScroller = YES;
        contentScrollView.autohidesScrollers = YES;
        contentScrollView.automaticallyAdjustsContentInsets = NO;
        contentScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:contentScrollView];

		// Setup the column headers
		NSRect columnHeaderFrame = NSMakeRect(0, 0,
											  frameRect.size.width,
											  MBTableGridColumnHeaderHeight);

		columnHeaderScrollView = [[NSScrollView alloc] initWithFrame:columnHeaderFrame];
		columnHeaderView = [[MBTableGridHeaderView alloc] initWithFrame:NSMakeRect(0, 0,
																				   columnHeaderFrame.size.width,
																				   columnHeaderFrame.size.height)
														   andTableGrid:self];
		columnHeaderView.orientation = MBTableHeaderHorizontalOrientation;
		columnHeaderScrollView.documentView = columnHeaderView;
		columnHeaderScrollView.drawsBackground = NO;
        columnHeaderScrollView.automaticallyAdjustsContentInsets = NO;
        columnHeaderScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        columnHeaderScrollView.verticalScrollElasticity = NSScrollElasticityNone;
		[self addSubview:columnHeaderScrollView];
        
        // Setup the footer view
        NSRect columnFooterFrame = NSMakeRect(0, frameRect.size.height - MBTableGridColumnFooterHeight,
                                              frameRect.size.width, MBTableGridColumnFooterHeight);
        
        columnFooterScrollView = [[NSScrollView alloc] initWithFrame:columnFooterFrame];
        columnFooterView = [[MBTableGridFooterView alloc] initWithFrame:NSMakeRect(0, 0,
                                                                                   columnFooterFrame.size.width,
                                                                                   columnFooterFrame.size.height)
                                                           andTableGrid:self];
        columnFooterScrollView.documentView = columnFooterView;
        columnFooterScrollView.drawsBackground = YES;
        columnFooterScrollView.automaticallyAdjustsContentInsets = NO;
        columnFooterScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        columnFooterScrollView.verticalScrollElasticity = NSScrollElasticityNone;
        [self addSubview:columnFooterScrollView];

		// Setup the row headers
		NSRect rowHeaderFrame = NSMakeRect(0, 0, MBTableGridRowHeaderWidth,
                                           self.frame.size.height);
		rowHeaderScrollView = [[NSScrollView alloc] initWithFrame:rowHeaderFrame];
		rowHeaderView = [[MBTableGridHeaderView alloc] initWithFrame:NSMakeRect(0, 0, rowHeaderFrame.size.width, rowHeaderFrame.size.height)
														andTableGrid:self];
		rowHeaderView.orientation = MBTableHeaderVerticalOrientation;
		rowHeaderScrollView.documentView = rowHeaderView;
		rowHeaderScrollView.drawsBackground = NO;
        rowHeaderScrollView.automaticallyAdjustsContentInsets = NO;
        rowHeaderScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        rowHeaderScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
		[self addSubview:rowHeaderScrollView];
        
        headerCornerView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, MBTableGridRowHeaderWidth, MBTableGridColumnHeaderHeight)];
        headerCornerView.material = NSVisualEffectMaterialSidebar;
        headerCornerView.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        headerCornerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:headerCornerView];
        
        footerCornerView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, self.frame.size.height - MBTableGridColumnFooterHeight,
                                                                                MBTableGridRowHeaderWidth, MBTableGridColumnFooterHeight)];
        footerCornerView.material = NSVisualEffectMaterialSidebar;
        footerCornerView.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        footerCornerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:footerCornerView];

        self.columnHeaderVisible = YES;
        self.rowHeaderVisible = YES;
        self.columnFooterVisible = YES;
        
        [self updateSubviewConstraints];
        [self updateSubviewInsets];

		// We want to synchronize the scroll views
        for (NSScrollView *scrollView in @[ contentScrollView, columnHeaderScrollView, rowHeaderScrollView, columnFooterScrollView ]) {
            [NSNotificationCenter.defaultCenter addObserver:self
                                                   selector:@selector(clipViewBoundsDidChange:)
                                                       name:NSViewBoundsDidChangeNotification
                                                     object:scrollView.contentView];
        }

        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(preferredScrollerStyleDidChange:)
                                                   name:NSPreferredScrollerStyleDidChangeNotification object:nil];
        
		// Set the default selection
		self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:0];
		self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:0];
		self.allowsMultipleSelection = YES;

		// Set the default sticky edges
		stickyColumnEdge = MBHorizontalEdgeLeft;
		stickyRowEdge = MBVerticalEdgeTop;

		singleClickCellEdit = NO;

        self.previousVerticalSelectionDirection = MBVerticalEdgeTop;
        self.previousHorizontalSelectionDirection = MBHorizontalEdgeLeft;
		
		self.columnRects = [NSMutableDictionary dictionary];
        [self registerForDraggedTypes:@[MBTableGridColumnDataType, MBTableGridRowDataType]];
        
        _textFinder = [[NSTextFinder alloc] init];
        _textFinder.findBarContainer = contentScrollView;
        _textFinder.incrementalSearchingEnabled = YES;
        _textFinder.incrementalSearchingShouldDimContentView = YES;
        
        _textFinderClient = [[MBTableGridTextFinderClient alloc] initWithTableGrid:self];
        _textFinder.client = _textFinderClient;

        self.wantsLayer = YES;
	}
	return self;
}

- (void) setShowsGrabHandles:(BOOL)s {
	showsGrabHandles = s;
	[self.contentView setShowsGrabHandle:s];
}

- (void)_sortButtonClickedForColumn:(NSUInteger)column {
    if (self.sortColumnIndex == column) {
        if (self.isSortColumnAscending) {
            self.sortColumnIndex = NSNotFound;
        } else {
            self.sortColumnAscending = YES;
        }
    } else {
        self.sortColumnIndex = column;
        self.sortColumnAscending = NO;
    }
    if ([self.delegate respondsToSelector:@selector(tableGrid:didSortByColumn:ascending:)]) {
        [self.delegate tableGrid:self didSortByColumn:self.sortColumnIndex ascending:self.sortColumnAscending];
    }
    [self reloadData];
}

- (void)setSortColumnIndex:(NSUInteger)sortColumnIndex {
    _sortColumnIndex = sortColumnIndex;
    columnHeaderView.needsDisplay = YES;
}

- (void)setSortColumnAscending:(BOOL)sortColumnAscending {
    _sortColumnAscending = sortColumnAscending;
    columnHeaderView.needsDisplay = YES;
}

- (void)awakeFromNib {
//	[self reloadData];
	[self unregisterDraggedTypes];
}

- (void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)isFlipped {
	return YES;
}

- (BOOL)canBecomeKeyView {
	return YES;
}

- (BOOL)acceptsFirstResponder {
	return YES;
}

- (NSCell*) _cellForColumn: (NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:cellForColumn:row:)]) {
		return [self.dataSource tableGrid:self cellForColumn:columnIndex row:rowIndex];
	}
	else {
		NSLog(@"WARNING: MBTableGrid data source does not implement tableGrid:cellForColumn:row:");
	}
	return nil;
}

- (id) _objectValueForColumn: (NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:objectValueForColumn:row:)]) {
		return [self.dataSource tableGrid:self objectValueForColumn:columnIndex row:rowIndex];
	}
	else {
		NSLog(@"WARNING: MBTableGrid data source does not implement tableGrid:objectValueForColumn:row:");
	}
	return nil;
}

- (void)setAutosaveName:(NSString *)autosaveName {
	_autosaveName = autosaveName;
	self.columnHeaderView.autosaveName = autosaveName;
}

- (void)drawRect:(NSRect)aRect {
	[NSColor.windowBackgroundColor set];
	NSRectFill(aRect);
}

#pragma mark Resize scrollview content size

- (void)resizeColumnWithIndex:(NSUInteger)columnIndex width:(float)w {
	// Set new width of column
	CGFloat currentWidth = w;
	
	[self.columnRects removeAllObjects];
	if (currentWidth < [self _minimumWidthForColumn:columnIndex]) {
		currentWidth = [self _minimumWidthForColumn:columnIndex];
	}
	[self _setWidth:currentWidth forColumn:columnIndex];
	
	self.needsDisplay = YES;
}

- (void)setNeedsDisplay:(BOOL)needsDisplay {
    super.needsDisplay = needsDisplay;
    
	self.contentView.needsDisplay = needsDisplay;
    columnHeaderView.needsDisplay = needsDisplay;
    rowHeaderView.needsDisplay = needsDisplay;
    columnFooterView.needsDisplay = needsDisplay;
}

#pragma mark Resize scrollview content size

/** Make sure we catch mouse down events inside the scrollview, but outside the table content view. */
- (NSView*) hitTest:(NSPoint)point {
	NSView* v = [super hitTest:point];

    // If a mouse click hit a clip view, clear the selection
    if (v == contentScrollView.contentView || v == columnHeaderScrollView.contentView ||
        v == rowHeaderScrollView.contentView || v == columnFooterScrollView.contentView) {
        if (self.window.currentEvent.type == NSEventTypeLeftMouseDown) {
			NSIndexSet* empty = [NSIndexSet indexSet];
			[self setSelectedRowIndexes:empty notify:YES];
			[self setSelectedColumnIndexes:empty notify:YES];
		}
	}
	return v;
}

- (CGFloat)resizeColumnWithIndex:(NSUInteger)columnIndex withDistance:(float)distance location:(NSPoint)location {
	// Note that we only need this rect for its origin, which won't be changing, otherwise we'd need to flush the column rect cache first
	NSRect columnRect = [self.contentView rectOfColumn:columnIndex];

	// Flush rect cache for this column because we're changing its size
	// Note that we're doing this after calling rectOfColumn: because that would cache the rect before we change its width...
	[self.columnRects removeAllObjects];

	// Set new width of column
	CGFloat currentWidth = [self _widthForColumn:columnIndex];
    CGFloat offset = 0.0;
    CGFloat minColumnWidth = [self _minimumWidthForColumn:columnIndex];

    if (currentWidth + distance <= minColumnWidth) {
        distance = -(currentWidth - minColumnWidth);
        currentWidth = minColumnWidth;
        offset = columnRect.origin.x - location.x + minColumnWidth;
    } else {
        currentWidth += distance;
    }
	
	[self _setWidth:currentWidth forColumn:columnIndex];
    
    // Update views with new sizes and mark the rightward columns as dirty
    for (NSView *horizontalView in @[ contentView, columnHeaderView, columnFooterView ]) {
        [horizontalView setFrameSize:NSMakeSize(NSWidth(horizontalView.frame) + distance, NSHeight(horizontalView.frame))];
        [horizontalView setNeedsDisplayInRect:NSMakeRect(columnRect.origin.x, 0,
                                                         NSWidth(horizontalView.bounds) - columnRect.origin.x,
                                                         NSHeight(horizontalView.bounds))];
    }
    
    return offset;
}

- (void)registerForDraggedTypes:(NSArray<NSPasteboardType> *)types {
	[super registerForDraggedTypes:types];

	// Register the content view for everything
	[contentView registerForDraggedTypes:types];
}

#pragma mark Mouse Events

- (void)mouseDown:(NSEvent *)theEvent {
	// End editing (if necessary)
	[self.cell endEditing:[self.window fieldEditor:NO forObject:contentView]];

	// If we're not the first responder, we need to be
	if (self.window.firstResponder != self) {
		[self.window makeFirstResponder:self];
	}
}

#pragma mark Keyboard Events

- (void)keyDown:(NSEvent *)theEvent {
	[self interpretKeyEvents:@[theEvent]];
}

/*- (void)interpretKeyEvents:(NSArray *)eventArray
   {

   }*/

#pragma mark NSResponder Event Handlers

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(paste:)) {
        return ([self.delegate respondsToSelector:@selector(tableGrid:pasteCellsAtColumns:rows:)]);
    }
    if (aSelector == @selector(copy:)) {
        return (self.selectedRowIndexes.count > 0 && self.selectedColumnIndexes.count > 0);
    }
    if (aSelector == @selector(delete:) || aSelector == @selector(deleteBackward:)) {
        return (self.selectedRowIndexes.count > 0 && self.selectedColumnIndexes.count > 0 &&
                ([self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumn:row:)] ||
                 [self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumns:rows:)]));
    }
    return [super respondsToSelector:aSelector];
}

- (void)copy:(id)sender {
	NSIndexSet *selectedColumns = [self selectedColumnIndexes];
	NSIndexSet *selectedRows = [self selectedRowIndexes];

    if ([self.delegate respondsToSelector:@selector(tableGrid:copyCellsAtColumns:rows:)]) {
		[self.delegate tableGrid:self copyCellsAtColumns:selectedColumns rows:selectedRows];
    } else {
        NSMutableString *string = [NSMutableString string];
        for (NSInteger row=selectedRows.firstIndex; row<=selectedRows.lastIndex; row++) {
            for (NSInteger columnIndex=selectedColumns.firstIndex; columnIndex<=selectedColumns.lastIndex; columnIndex++) {
                NSString *value = [self.dataSource tableGrid:self objectValueForColumn:columnIndex row:row];
                if (value)
                    [string appendString:value];
                if (columnIndex<selectedColumns.lastIndex)
                    [string appendString:@"\t"];
            }
            if (row<selectedRows.lastIndex)
                [string appendString:@"\n"];
        }
        
        NSPasteboard *pboard = NSPasteboard.generalPasteboard;
        
        [pboard declareTypes:@[ NSPasteboardTypeTabularText, NSPasteboardTypeString ]
                       owner:nil];
        
        [pboard setString:string forType:NSPasteboardTypeTabularText];
        [pboard setString:string forType:NSPasteboardTypeString];
    }
}

- (void)paste:(id)sender {
	
    NSIndexSet *selectedColumns = [self selectedColumnIndexes];
    NSIndexSet *selectedRows = [self selectedRowIndexes];
    
    if ([self.delegate respondsToSelector:@selector(tableGrid:pasteCellsAtColumns:rows:)]) {
        [self.delegate tableGrid:self pasteCellsAtColumns:selectedColumns rows:selectedRows];
        [self reloadData];
    }
}

- (void)insertTab:(id)sender {
	// Pressing "Tab" moves to the next column
	[self moveRight:sender];

	if(self.singleClickCellEdit) {
		[self.contentView editSelectedCell:nil text:@""];
	}
}

- (void)insertBacktab:(id)sender {
	// Pressing Shift+Tab moves to the previous column
	[self moveLeft:sender];

	if (self.singleClickCellEdit) {
		[self.contentView editSelectedCell:nil text:@""];
	}
}

- (void)insertNewline:(id)sender {
    if (NSApp.currentEvent.modifierFlags & NSEventModifierFlagShift) {
		// Pressing Shift+Return moves to the previous row
		[self moveUp:sender];
	}
	else {
		// Pressing Return moves to the next row
		[self moveDown:sender];
	}

	if (self.singleClickCellEdit) {
		[self.contentView editSelectedCell:nil text:@""];
	}
}

- (void)moveUp:(id)sender {
	NSUInteger column = self.selectedColumnIndexes.firstIndex;
	NSUInteger row = self.selectedRowIndexes.firstIndex;

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBHorizontalEdgeRight) {
		column = self.selectedColumnIndexes.lastIndex;
	}
	if (stickyRowEdge == MBVerticalEdgeBottom) {
		row = self.selectedRowIndexes.lastIndex;
	}

    if (row <= 0) { return; }

	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:column];
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:(row - 1)];

    [self scrollSelectionToVisible];
}

- (void)moveUpAndModifySelection:(id)sender {
	NSUInteger firstRow = self.selectedRowIndexes.firstIndex;
	NSUInteger lastRow = self.selectedRowIndexes.lastIndex;

	// If there is only one row selected, change the sticky edge to the bottom
	if (self.selectedRowIndexes.count == 1) {
		stickyRowEdge = MBVerticalEdgeBottom;
	}

	// We can't expand past the first row
	if (stickyRowEdge == MBVerticalEdgeBottom && firstRow <= 0) { return; }

	if (stickyRowEdge == MBVerticalEdgeTop) {
		// If the top edge is sticky, contract the selection
		lastRow--;
	}
	else if (stickyRowEdge == MBVerticalEdgeBottom) {
		// If the bottom edge is sticky, expand the selection
		firstRow--;
	}
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRow, lastRow - firstRow + 1)];

    [self scrollSelectionToVisibleShowingVerticalEdge:MBOppositeVerticalEdge(stickyRowEdge)];
}

- (void)moveDown:(id)sender {
	NSUInteger column = self.selectedColumnIndexes.firstIndex;
	NSUInteger row = self.selectedRowIndexes.firstIndex;

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBHorizontalEdgeRight) {
		column = self.selectedColumnIndexes.lastIndex;
	}
	if (stickyRowEdge == MBVerticalEdgeBottom) {
		row = self.selectedRowIndexes.lastIndex;
	}

    if (row >= (_numberOfRows - 1)) { return; }

	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:column];
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:(row + 1)];

    [self scrollSelectionToVisible];
}

- (void)moveDownAndModifySelection:(id)sender {
	NSUInteger firstRow = self.selectedRowIndexes.firstIndex;
	NSUInteger lastRow = self.selectedRowIndexes.lastIndex;

	// If there is only one row selected, change the sticky edge to the top
	if (self.selectedRowIndexes.count == 1) {
		stickyRowEdge = MBVerticalEdgeTop;
	}

	// We can't expand past the last row
	if (stickyRowEdge == MBVerticalEdgeTop && lastRow >= (_numberOfRows - 1))
		return;

	if (stickyRowEdge == MBVerticalEdgeTop) {
		// If the top edge is sticky, contract the selection
		lastRow++;
	}
	else if (stickyRowEdge == MBVerticalEdgeBottom) {
		// If the bottom edge is sticky, expand the contraction
		firstRow++;
	}
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRow, lastRow - firstRow + 1)];

    [self scrollSelectionToVisibleShowingVerticalEdge:MBOppositeVerticalEdge(stickyRowEdge)];
}

- (void)moveLeft:(id)sender {
	NSUInteger column = self.selectedColumnIndexes.firstIndex;
	NSUInteger row = self.selectedRowIndexes.firstIndex;

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBHorizontalEdgeRight) {
		column = self.selectedColumnIndexes.lastIndex;
	}
	if (stickyRowEdge == MBVerticalEdgeBottom) {
		row = self.selectedRowIndexes.lastIndex;
	}

    if (column == 0)
        return;

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:(column - 1)];
    self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];

    [self scrollSelectionToVisible];
}

- (void)moveLeftAndModifySelection:(id)sender {
	NSUInteger firstColumn = self.selectedColumnIndexes.firstIndex;
	NSUInteger lastColumn = self.selectedColumnIndexes.lastIndex;

	// If there is only one column selected, change the sticky edge to the right
	if (self.selectedColumnIndexes.count == 1) {
		stickyColumnEdge = MBHorizontalEdgeRight;
	}

	// We can't expand past the first column
    if (stickyColumnEdge == MBHorizontalEdgeRight && firstColumn <= 0) { return; }

	if (stickyColumnEdge == MBHorizontalEdgeLeft) {
		// If the top edge is sticky, contract the selection
		lastColumn--;
	}
	else if (stickyColumnEdge == MBHorizontalEdgeRight) {
		// If the bottom edge is sticky, expand the contraction
		firstColumn--;
	}
	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumn, lastColumn - firstColumn + 1)];

    [self scrollSelectionToVisibleShowingHorizontalEdge:MBOppositeHorizontalEdge(stickyColumnEdge)];
}

- (void)moveRight:(id)sender {
	NSUInteger column = self.selectedColumnIndexes.firstIndex;
	NSUInteger row = self.selectedRowIndexes.firstIndex;

	// Accomodate for the sticky edges
	if (stickyColumnEdge == MBHorizontalEdgeRight) {
		column = self.selectedColumnIndexes.lastIndex;
	}
	if (stickyRowEdge == MBVerticalEdgeBottom) {
		row = self.selectedRowIndexes.lastIndex;
	}

    if (column >= (_numberOfColumns - 1))
        return;

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:(column + 1)];
    self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];

    [self scrollSelectionToVisible];
}

- (void)moveRightAndModifySelection:(id)sender {
    NSUInteger firstColumn = self.selectedColumnIndexes.firstIndex;
    NSUInteger lastColumn = self.selectedColumnIndexes.lastIndex;

    // If there is only one column selected, change the sticky edge to the left
    if (self.selectedColumnIndexes.count == 1) {
        stickyColumnEdge = MBHorizontalEdgeLeft;
    }

    // We can't expand past the last column
    if (stickyColumnEdge == MBHorizontalEdgeLeft && lastColumn >= (_numberOfColumns - 1)) { return; }

    if (stickyColumnEdge == MBHorizontalEdgeLeft) {
        // If the left edge is sticky, expand the selection
        lastColumn++;
    }
    else if (stickyColumnEdge == MBHorizontalEdgeRight) {
        // If the right edge is sticky, contract the selection
        firstColumn++;
    }
    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumn, lastColumn - firstColumn + 1)];

    [self scrollSelectionToVisibleShowingHorizontalEdge:MBOppositeHorizontalEdge(stickyColumnEdge)];
}

- (void)moveToBeginningOfDocument:(id)sender {
    NSUInteger column = self.selectedColumnIndexes.firstIndex;

    // Accomodate for the sticky edges
    if (stickyColumnEdge == MBHorizontalEdgeRight) {
        column = self.selectedColumnIndexes.lastIndex;
    }

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:column];
    self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:0];

    [self scrollSelectionToVisible];
}

- (void)moveToBeginningOfDocumentAndModifySelection:(id)sender {
    NSUInteger firstRow = self.selectedRowIndexes.firstIndex;
    NSUInteger lastRow = self.selectedRowIndexes.lastIndex;

    if (stickyRowEdge == MBVerticalEdgeTop) {
        // If the top edge is sticky, contract the selection and switch stickiness
        lastRow = firstRow;
        stickyRowEdge = MBVerticalEdgeBottom;
    }

    firstRow = 0;

    self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRow, lastRow - firstRow + 1)];

    [self scrollSelectionToVisibleShowingVerticalEdge:MBOppositeVerticalEdge(stickyRowEdge)];
}

- (void)moveToEndOfDocument:(id)sender {
    NSUInteger column = self.selectedColumnIndexes.firstIndex;

    // Accomodate for the sticky edges
    if (stickyColumnEdge == MBHorizontalEdgeRight) {
        column = self.selectedColumnIndexes.lastIndex;
    }

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:column];
    self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:_numberOfRows - 1];

    [self scrollSelectionToVisible];
}

- (void)moveToEndOfDocumentAndModifySelection:(id)sender {
    NSUInteger firstRow = self.selectedRowIndexes.firstIndex;
    NSUInteger lastRow = self.selectedRowIndexes.lastIndex;

    if (stickyRowEdge == MBVerticalEdgeBottom) {
        // If the bottom edge is sticky, contract the selection and switch stickiness
        firstRow = lastRow;
        stickyRowEdge = MBVerticalEdgeTop;
    }

    lastRow = (_numberOfRows - 1);

    self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRow, lastRow - firstRow + 1)];

    [self scrollSelectionToVisibleShowingVerticalEdge:MBOppositeVerticalEdge(stickyRowEdge)];
}

- (void)moveToBeginningOfLine:(id)sender {
    NSUInteger row = self.selectedRowIndexes.firstIndex;

    // Accomodate for the sticky edges
    if (stickyRowEdge == MBVerticalEdgeBottom) {
        row = self.selectedRowIndexes.lastIndex;
    }

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:0];
    self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];

    [self scrollSelectionToVisible];
}

- (void)moveToBeginningOfLineAndModifySelection:(id)sender {
    NSUInteger firstColumn = self.selectedColumnIndexes.firstIndex;
    NSUInteger lastColumn = self.selectedColumnIndexes.lastIndex;

    if (stickyColumnEdge == MBHorizontalEdgeLeft) {
        // If the left edge is sticky, contract the selection and switch stickiness
        lastColumn = firstColumn;
        stickyColumnEdge = MBHorizontalEdgeRight;
    }

    firstColumn = 0;

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumn, lastColumn - firstColumn + 1)];

    [self scrollSelectionToVisibleShowingHorizontalEdge:MBOppositeHorizontalEdge(stickyColumnEdge)];
}

- (void)moveToEndOfLine:(id)sender {
    NSUInteger row = self.selectedRowIndexes.firstIndex;

    // Accomodate for the sticky edges
    if (stickyRowEdge == MBVerticalEdgeBottom) {
        row = self.selectedRowIndexes.lastIndex;
    }

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:_numberOfColumns-1];
    self.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];

    [self scrollSelectionToVisible];
}

- (void)moveToEndOfLineAndModifySelection:(id)sender {
    NSUInteger firstColumn = self.selectedColumnIndexes.firstIndex;
    NSUInteger lastColumn = self.selectedColumnIndexes.lastIndex;

    if (stickyColumnEdge == MBHorizontalEdgeRight) {
        // If the right edge is sticky, contract the selection and switch stickiness
        firstColumn = lastColumn;
        stickyColumnEdge = MBHorizontalEdgeLeft;
    }

    lastColumn = (_numberOfColumns - 1);

    self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumn, lastColumn - firstColumn + 1)];

    [self scrollSelectionToVisibleShowingHorizontalEdge:MBOppositeHorizontalEdge(stickyColumnEdge)];
}

/**
 Scrolls the minimum distance required to make the selection fully visible.

 Use to put top-left corner or single cells into focus. Not animated. */
- (void)scrollSelectionToVisible
{
    // Single-cell selection equals top-left expansion.
    [self scrollSelectionToVisibleShowingHorizontalEdge:MBHorizontalEdgeLeft
                                           verticalEdge:MBVerticalEdgeTop];
}

/**
 Scrolls the minimum distance required to make the selection visible at the edge defined by @p vertical.

 @param vertical Direction in which to expand the selection.
 */
- (void)scrollSelectionToVisibleShowingVerticalEdge:(MBVerticalEdge)vertical
{
    [self scrollSelectionToVisibleShowingHorizontalEdge:self.previousHorizontalSelectionDirection
                                           verticalEdge:vertical];
}

/**
 Scrolls the minimum distance required to make the selection visible at the edge defined by @p horizontal.

 @param horizontal Direction in which to expand the selection.
 */
- (void)scrollSelectionToVisibleShowingHorizontalEdge:(MBHorizontalEdge)horizontal
{
    [self scrollSelectionToVisibleShowingHorizontalEdge:horizontal
                                           verticalEdge:self.previousVerticalSelectionDirection];
}

- (void)scrollSelectionToVisibleShowingHorizontalEdge:(MBHorizontalEdge)horizontal verticalEdge:(MBVerticalEdge)vertical
{
    // Cache latest direction to keep orientation when using the keyboard to expand the selection.
    self.previousHorizontalSelectionDirection = horizontal;
    self.previousVerticalSelectionDirection = vertical;

    NSUInteger column = [self.selectedColumnIndexes indexForExpansionInHorizontalDirection:horizontal];
    NSUInteger row = [self.selectedRowIndexes indexForExpansionInVerticalDirection:vertical];

    if (column > self.numberOfColumns) { return; }

    NSRect visibleRect = contentScrollView.insetDocumentVisibleRect;
    NSRect cellRect = [self frameOfCellAtColumn:column row:row];
    cellRect = [self convertRect:cellRect toView:contentScrollView.contentView];

    if (NSContainsRect(visibleRect, cellRect)) {
        return;
    }

    NSPoint scrollDelta = NSMakePoint(0, 0);

    if (NSMinX(cellRect) < NSMinX(visibleRect)) {
        scrollDelta.x = NSMinX(cellRect) - NSMinX(visibleRect);
    } else if (NSMaxX(cellRect) > NSMaxX(visibleRect)) {
        scrollDelta.x = NSMaxX(cellRect) - NSMaxX(visibleRect);
    }

    if (NSMinY(cellRect) < NSMinY(visibleRect)) {
        scrollDelta.y = NSMinY(cellRect) - NSMinY(visibleRect);
    } else if (NSMaxY(cellRect) > NSMaxY(visibleRect)) {
        scrollDelta.y = NSMaxY(cellRect) - NSMaxY(visibleRect);
    }

    NSPoint scrollOffset = contentScrollView.contentView.bounds.origin;
    scrollOffset.x += scrollDelta.x;
    scrollOffset.y += scrollDelta.y;
    [contentScrollView.contentView scrollToPoint:scrollOffset];
}

- (void)scrollToArea:(NSRect)area animate:(BOOL)shouldAnimate {
	if (shouldAnimate) {
		[NSAnimationContext runAnimationGroup: ^(NSAnimationContext *context) {
		    context.allowsImplicitAnimation = YES;
		    [self.contentView scrollRectToVisible:area];
		} completionHandler: ^{ }];
	}
	else {
        [contentScrollView.contentView scrollRectToVisible:area];
	}
}

- (void)scrollPageDown:(id)sender {
    NSPoint point = contentScrollView.contentView.bounds.origin;
    point.y += (contentScrollView.bounds.size.height - contentScrollView.verticalPageScroll);
    if (point.y > self.contentView.bounds.size.height - contentScrollView.bounds.size.height)
        point.y = self.contentView.bounds.size.height - contentScrollView.bounds.size.height;

    [self scrollToPoint:point animate:YES];
}

- (void)scrollPageUp:(id)sender {
    NSPoint point = contentScrollView.contentView.bounds.origin;
    point.y -= (contentScrollView.bounds.size.height - contentScrollView.verticalPageScroll);
    if (point.y < 0.0)
        point.y = 0.0;

    [self scrollToPoint:point animate:YES];
}

- (void)scrollToEndOfDocument:(id)sender {
    NSPoint point = contentScrollView.contentView.bounds.origin;
    point.y = (self.contentView.bounds.size.height - contentScrollView.bounds.size.height);
    [self scrollToPoint:point animate:YES];
}

- (void)scrollToBeginningOfDocument:(id)sender {
    NSPoint point = contentScrollView.contentView.bounds.origin;
    point.y = 0.0;
    [self scrollToPoint:point animate:YES];
}

- (void)scrollToPoint:(NSPoint)point animate:(BOOL)shouldAnimate {
    if (shouldAnimate) {
        [NSAnimationContext runAnimationGroup: ^(NSAnimationContext *context) {
            context.allowsImplicitAnimation = YES;
            [contentScrollView.contentView scrollToPoint:point];
            [contentScrollView reflectScrolledClipView:contentScrollView.contentView];
        } completionHandler: ^{

        }];
    } else {
        [contentScrollView.contentView scrollToPoint:point];
    }
}

- (void)selectAll:(id)sender {
	stickyColumnEdge = MBHorizontalEdgeLeft;
	stickyRowEdge = MBVerticalEdgeTop;

	self.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _numberOfColumns)];
	self.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _numberOfRows)];
}

// Interpreted by interpretKeyEvents:
- (void)deleteBackward:(id)sender {
	// Clear the contents of every selected cell
    [self _setObjectValue:nil forColumns:self.selectedColumnIndexes rows:self.selectedRowIndexes];
	[self reloadData];
}

// From the Edit menu
- (void)delete:(id)sender {
    [self deleteBackward:sender];
}

- (void)insertText:(id)aString {
	NSUInteger column = self.selectedColumnIndexes.firstIndex;
	NSUInteger row = self.selectedRowIndexes.firstIndex;
	NSCell *selectedCell = [self _cellForColumn:column row:row];

	[contentView editSelectedCell:self text:aString];
	
	if ([selectedCell isKindOfClass:[MBTableGridCell class]]) {
		// Insert the typed string into the field editor
		NSText *fieldEditor = [self.window fieldEditor:YES forObject:contentView];
		fieldEditor.delegate = contentView;
		fieldEditor.string = aString;
		
		// The textDidBeginEditing notification isn't sent yet, so invoke a custom method
		[contentView textDidBeginEditingWithEditor:fieldEditor];
	}
	self.needsDisplay = YES;
}

#pragma mark -
#pragma mark Find Bar Support

- (IBAction)performTextFinderAction:(NSControl *)sender {
    [_textFinder performAction:sender.tag];
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
    if (item.action == @selector(performTextFinderAction:)) {
        return [_textFinder validateAction:item.tag];
    }
    return YES;
}

- (BOOL)_shouldAbortFindOperation {
    if (NSThread.isMainThread)
        return self.isHiddenOrHasHiddenAncestor || !contentScrollView.findBarVisible;
    
    __block BOOL return_value = NO;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        return_value = self.isHiddenOrHasHiddenAncestor || !self->contentScrollView.findBarVisible;
    }];
    [NSOperationQueue.mainQueue addOperations:@[ operation ] waitUntilFinished:YES];
    return return_value;
}

- (BOOL)isFindBarVisible {
    return contentScrollView.isFindBarVisible;
}

- (void)setFindBarVisible:(BOOL)findBarVisible {
    contentScrollView.findBarVisible = findBarVisible;
}

#pragma mark -
#pragma mark Notifications

- (void)synchronizeScrollView:(NSScrollView *)scrollView withChangedBoundsOrigin:(NSPoint)changedBoundsOrigin horizontal:(BOOL)horizontal {
    // Get the current origin
    NSPoint curOffset = scrollView.contentView.bounds.origin;
    NSPoint newOffset = curOffset;
    
    if (horizontal) {
        newOffset.x = changedBoundsOrigin.x;
    } else {
        newOffset.y = changedBoundsOrigin.y;
    }
    
    // If the synced position is different from our current position, reposition the view
    if (!NSEqualPoints(curOffset, newOffset)) {
        [scrollView.contentView scrollToPoint:newOffset];
        // We have to tell the NSScrollView to update its scrollers
        [scrollView reflectScrolledClipView:scrollView.contentView];
    }
}

- (void)synchronizeScrollViewsWithScrollView:(NSScrollView *)scrollView {
    NSPoint changedBoundsOrigin = scrollView.contentView.bounds.origin;
    for (NSScrollView *targetScrollView in @[ contentScrollView, rowHeaderScrollView, columnHeaderScrollView, columnFooterScrollView ]) {
        if (targetScrollView == scrollView)
            continue;
        
        if (NSWidth(scrollView.documentView.frame) > NSWidth(scrollView.insetFrame) && NSWidth(scrollView.frame) > 0.0 &&
            NSWidth(targetScrollView.documentView.frame) > NSWidth(targetScrollView.insetFrame)) {
            [self synchronizeScrollView:targetScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:YES];
        }
        if (NSHeight(scrollView.documentView.frame) > NSHeight(scrollView.insetFrame) && NSHeight(scrollView.frame) > 0.0 &&
            NSHeight(targetScrollView.documentView.frame) > NSHeight(targetScrollView.insetFrame)) {
            [self synchronizeScrollView:targetScrollView withChangedBoundsOrigin:changedBoundsOrigin horizontal:NO];
        }
    }
    [self.window invalidateCursorRectsForView:self];
}

- (void)clipViewBoundsDidChange:(NSNotification *)aNotification {
    for (NSScrollView *scrollView in @[ contentScrollView, rowHeaderScrollView, columnHeaderScrollView, columnFooterScrollView ]) {
        if (scrollView.contentView == aNotification.object) {
            [self synchronizeScrollViewsWithScrollView:scrollView];
            return;
        }
    }
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark NSDraggingSource

-(NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    
    switch(context) {
        case NSDraggingContextOutsideApplication:
            return NSDragOperationNone;
            break;
            
        case NSDraggingContextWithinApplication:
        default:
            return NSDragOperationMove;
            break;
    }
}

#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo> )sender {
	NSPasteboard *pboard = sender.draggingPasteboard;
	NSData *columnData = [pboard dataForType:MBTableGridColumnDataType];
	NSData *rowData = [pboard dataForType:MBTableGridRowDataType];

	// Do not accept drag if this doesn't come from us
	if (sender.draggingSource != self) {
		return NO;
	}

	if (columnData) {
		return NSDragOperationMove;
	}
	else if (rowData) {
		return NSDragOperationMove;
	}
	else {
		if ([self.dataSource respondsToSelector:@selector(tableGrid:validateDrop:proposedColumn:row:)]) {
			NSPoint mouseLocation = [self convertPoint:sender.draggingLocation fromView:nil];
			NSUInteger dropColumn = [self columnAtPoint:mouseLocation];
			NSUInteger dropRow = [self rowAtPoint:mouseLocation];

			NSDragOperation dragOperation = [self.dataSource tableGrid:self validateDrop:sender proposedColumn:dropColumn row:dropRow];

			// If the drag is okay, highlight the appropriate cell
			if (dragOperation != NSDragOperationNone) {
				[contentView _setDropColumn:dropColumn];
				[contentView _setDropRow:dropRow];
			}

			return dragOperation;
		}
	}

	return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo> )sender {
	NSPasteboard *pboard = sender.draggingPasteboard;
	NSData *columnData = [pboard dataForType:MBTableGridColumnDataType];
	NSData *rowData = [pboard dataForType:MBTableGridRowDataType];
	NSPoint mouseLocation = [self convertPoint:sender.draggingLocation fromView:nil];

	if (columnData) {
		// If we're dragging a column

		NSUInteger dropColumn = [self _dropColumnForPoint:mouseLocation];

		if (dropColumn == NSNotFound) {
			return NSDragOperationNone;
		}

		NSIndexSet *draggedColumns = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:columnData];

		BOOL canDrop = NO;
		if ([self.dataSource respondsToSelector:@selector(tableGrid:canMoveColumns:toIndex:)]) {
			canDrop = [self.dataSource tableGrid:self canMoveColumns:draggedColumns toIndex:dropColumn];
		}

		[contentView _setDraggingColumnOrRow:YES];

		if (canDrop) {
			[contentView _setDropColumn:dropColumn];
			return NSDragOperationMove;
		}
		else {
			[contentView _setDropColumn:NSNotFound];
		}
	}
	else if (rowData) {
		// If we're dragging a row

		NSUInteger dropRow = [self _dropRowForPoint:mouseLocation];

		if (dropRow == NSNotFound) {
			return NSDragOperationNone;
		}

		NSIndexSet *draggedRows = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:rowData];

		BOOL canDrop = NO;
		if ([self.dataSource respondsToSelector:@selector(tableGrid:canMoveRows:toIndex:)]) {
			canDrop = [self.dataSource tableGrid:self canMoveRows:draggedRows toIndex:dropRow];
		}

		[contentView _setDraggingColumnOrRow:YES];

		if (canDrop) {
			[contentView _setDropRow:dropRow];
			return NSDragOperationMove;
		}
		else {
			[contentView _setDropRow:NSNotFound];
		}
	}
	else {
		if ([self.dataSource respondsToSelector:@selector(tableGrid:validateDrop:proposedColumn:row:)]) {
			NSUInteger dropColumn = [self columnAtPoint:mouseLocation];
			NSUInteger dropRow = [self rowAtPoint:mouseLocation];

			[contentView _setDraggingColumnOrRow:NO];

			NSDragOperation dragOperation = [self.dataSource tableGrid:self validateDrop:sender proposedColumn:dropColumn row:dropRow];

			// If the drag is okay, highlight the appropriate cell
			if (dragOperation != NSDragOperationNone) {
				[contentView _setDropColumn:dropColumn];
				[contentView _setDropRow:dropRow];
			}

			return dragOperation;
		}
	}
	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo> )sender {
	[contentView _setDropColumn:NSNotFound];
	[contentView _setDropRow:NSNotFound];
}

- (void)draggingEnded:(id <NSDraggingInfo> )sender {
	[contentView _setDropColumn:NSNotFound];
	[contentView _setDropRow:NSNotFound];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo> )sender {
	// Do not accept drag if this doesn't come from us
	if([sender draggingSource] != self) {
		return NO;
	}
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo> )sender {
	NSPasteboard *pboard = sender.draggingPasteboard;
	NSData *columnData = [pboard dataForType:MBTableGridColumnDataType];
	NSData *rowData = [pboard dataForType:MBTableGridRowDataType];
	NSPoint mouseLocation = [self convertPoint:sender.draggingLocation fromView:nil];

	// Do not accept drag if this doesn't come from us
	if(sender.draggingSource != self) {
		return NO;
	}

	if (columnData) {
		// If we're dragging a column
		if ([self.dataSource respondsToSelector:@selector(tableGrid:moveColumns:toIndex:)]) {
			// Get which columns are being dragged
			NSIndexSet *draggedColumns = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:columnData];

			// Get the index to move the columns to
			NSUInteger dropColumn = [self _dropColumnForPoint:mouseLocation];

			// Tell the data source to move the columns
			BOOL didDrag = [self.dataSource tableGrid:self moveColumns:draggedColumns toIndex:dropColumn];

			if (didDrag) {
				NSUInteger startIndex = dropColumn;
				NSUInteger length = draggedColumns.count;

                if (dropColumn > draggedColumns.lastIndex) {
                    startIndex -= length;
                } else if (dropColumn >= draggedColumns.firstIndex) {
                    startIndex = draggedColumns.firstIndex;
                }

				NSIndexSet *newColumns = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(startIndex, length)];

				// Post the notification
				[NSNotificationCenter.defaultCenter postNotificationName:MBTableGridDidMoveColumnsNotification object:self userInfo:@{ @"OldColumns": draggedColumns, @"NewColumns": newColumns }];

				// Change the selection to reflect the newly-dragged columns
				self.selectedColumnIndexes = newColumns;
			}

			return didDrag;
		}
	}
	else if (rowData) {
		// If we're dragging a row
		if ([self.dataSource respondsToSelector:@selector(tableGrid:moveRows:toIndex:)]) {
			// Get which rows are being dragged
			NSIndexSet *draggedRows = (NSIndexSet *)[NSKeyedUnarchiver unarchiveObjectWithData:rowData];

			// Get the index to move the rows to
			NSUInteger dropRow = [self _dropRowForPoint:mouseLocation];

			// Tell the data source to move the rows
			BOOL didDrag = [self.dataSource tableGrid:self moveRows:draggedRows toIndex:dropRow];

			if (didDrag) {
				NSUInteger startIndex = dropRow;
				NSUInteger length = draggedRows.count;

        if (dropRow > draggedRows.lastIndex) {
            startIndex -= length;
        } else if (dropRow >= draggedRows.firstIndex) {
            startIndex = draggedRows.firstIndex;
        }

				NSIndexSet *newRows = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(startIndex, length)];

				// Post the notification
				[NSNotificationCenter.defaultCenter postNotificationName:MBTableGridDidMoveRowsNotification object:self userInfo:@{ @"OldRows": draggedRows, @"NewRows": newRows }];

				// Change the selection to reflect the newly-dragged rows
				self.selectedRowIndexes = newRows;
			}

			return didDrag;
		}
	}
	else {
		if ([self.dataSource respondsToSelector:@selector(tableGrid:acceptDrop:column:row:)]) {
			NSUInteger dropColumn = [self columnAtPoint:mouseLocation];
			NSUInteger dropRow = [self rowAtPoint:mouseLocation];

			// Pass the drag to the data source
			BOOL didPerformDrag = [self.dataSource tableGrid:self acceptDrop:sender column:dropColumn row:dropRow];

			return didPerformDrag;
		}
	}

	return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo> )sender {
	[contentView _setDropColumn:NSNotFound];
	[contentView _setDropRow:NSNotFound];
}

#pragma mark -
#pragma mark Subclass Methods

#pragma mark Dimensions


#pragma mark Reloading the Grid

// Called after updating the table grid's contentInsets
- (void)updateSubviewConstraints {
    [self removeConstraints:self.constraints];

    [columnHeaderScrollView.topAnchor constraintEqualToAnchor:self.topAnchor constant:_contentInsets.top].active = YES;
    [columnHeaderScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
    [columnHeaderScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
    
    [columnFooterScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-_contentInsets.bottom].active = YES;
    [columnFooterScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
    [columnFooterScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
    
    [contentScrollView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
    [contentScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
    [contentScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
    [contentScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;

    [rowHeaderScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_contentInsets.left].active = YES;
    [rowHeaderScrollView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
    [rowHeaderScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
    
    [headerCornerView.leadingAnchor constraintEqualToAnchor:rowHeaderScrollView.leadingAnchor].active = YES;
    [headerCornerView.topAnchor constraintEqualToAnchor:columnHeaderScrollView.topAnchor].active = YES;
    [headerCornerView.trailingAnchor constraintEqualToAnchor:rowHeaderScrollView.trailingAnchor].active = YES;
    [headerCornerView.bottomAnchor constraintEqualToAnchor:columnHeaderScrollView.bottomAnchor].active = YES;
    
    [footerCornerView.leadingAnchor constraintEqualToAnchor:rowHeaderScrollView.leadingAnchor].active = YES;
    [footerCornerView.bottomAnchor constraintEqualToAnchor:columnFooterScrollView.bottomAnchor].active = YES;
    [footerCornerView.trailingAnchor constraintEqualToAnchor:rowHeaderScrollView.trailingAnchor].active = YES;
    [footerCornerView.topAnchor constraintEqualToAnchor:columnFooterScrollView.topAnchor].active = YES;
    
}

- (void)updateSubviewInsets {
    self.needsLayout = YES;
    [self layoutSubtreeIfNeeded];
    columnHeaderScrollView.contentInsets = NSEdgeInsetsMake(0, rowHeaderScrollView.frame.size.width + _contentInsets.left,
                                                            0, _contentInsets.right);
    columnFooterScrollView.contentInsets = NSEdgeInsetsMake(0, rowHeaderScrollView.frame.size.width + _contentInsets.left,
                                                            0, _contentInsets.right);
    contentScrollView.contentInsets = NSEdgeInsetsMake(columnHeaderScrollView.frame.size.height + _contentInsets.top,
                                                       rowHeaderScrollView.frame.size.width + _contentInsets.left,
                                                       columnFooterScrollView.frame.size.height + _contentInsets.bottom,
                                                       _contentInsets.right);
    rowHeaderScrollView.contentInsets = NSEdgeInsetsMake(columnHeaderScrollView.frame.size.height + _contentInsets.top, 0,
                                                         columnFooterScrollView.frame.size.height + _contentInsets.bottom, 0);
}

- (void)updateAuxiliaryViewSizes {
    NSSize contentRectSize = contentView.frame.size;

	// Update the column header view's size
    NSSize columnHeaderSize = NSMakeSize(contentRectSize.width, NSHeight(columnHeaderView.frame));
    if (!contentScrollView.verticalScroller.isHidden && contentScrollView.scrollerStyle == NSScrollerStyleLegacy) {
        columnHeaderSize.width += [NSScroller scrollerWidthForControlSize:NSControlSizeRegular
                                                            scrollerStyle:contentScrollView.scrollerStyle];
    }
    [columnHeaderView setFrameSize:columnHeaderSize];

    // Update the row header view's size
    NSSize rowHeaderSize = NSMakeSize(NSWidth(rowHeaderView.frame), contentRectSize.height);
    if (!contentScrollView.horizontalScroller.isHidden && contentScrollView.scrollerStyle == NSScrollerStyleLegacy) {
        rowHeaderSize.height += [NSScroller scrollerWidthForControlSize:NSControlSizeRegular
                                                          scrollerStyle:contentScrollView.scrollerStyle];
    }
    [rowHeaderView setFrameSize:rowHeaderSize];

    // Update the colunm footer view's size
    NSSize columnFooterSize = NSMakeSize(contentRectSize.width, NSHeight(columnFooterView.frame));
    if (!contentScrollView.verticalScroller.isHidden && contentScrollView.scrollerStyle == NSScrollerStyleLegacy) {
        columnFooterSize.width += [NSScroller scrollerWidthForControlSize:NSControlSizeRegular
                                                            scrollerStyle:contentScrollView.scrollerStyle];
    }
    [columnFooterView setFrameSize:columnFooterSize];
}

- (void)preferredScrollerStyleDidChange:(NSNotification *)notification {
    [self updateAuxiliaryViewSizes];
}

- (void)reloadData {
	CGRect visibleRect = contentScrollView.insetDocumentVisibleRect;
	
	// Set number of columns
	if ([self.dataSource respondsToSelector:@selector(numberOfColumnsInTableGrid:)]) {
		_numberOfColumns =  [self.dataSource numberOfColumnsInTableGrid:self];
	}
	else {
		_numberOfColumns = 0;
	}

	// Set number of rows
	if ([self.dataSource respondsToSelector:@selector(numberOfRowsInTableGrid:)]) {
		_numberOfRows =  [self.dataSource numberOfRowsInTableGrid:self];
	}
	else {
		_numberOfRows = 0;
	}
        
    if ([self.dataSource respondsToSelector:@selector(sortableColumnIndexesInTableGrid:)])
        columnHeaderView.indicatorImageColumns = [self.dataSource sortableColumnIndexesInTableGrid:self];
    
	// Update the content view's size
    NSUInteger lastColumn = (_numberOfColumns>0) ? _numberOfColumns-1 : 0;
    NSUInteger lastRow = (_numberOfRows>0) ? _numberOfRows-1 : 0;
	NSRect bottomRightCellFrame = [contentView frameOfCellAtColumn:lastColumn row:lastRow];

	NSSize contentRectSize = NSMakeSize(NSMaxX(bottomRightCellFrame), NSMaxY(bottomRightCellFrame));
	[contentView setFrameSize:contentRectSize];

    [self updateAuxiliaryViewSizes];

	if(_numberOfRows > 0) {
		if((visibleRect.size.height + visibleRect.origin.y) > contentRectSize.height) {
			visibleRect.size.height = MIN(contentRectSize.height, visibleRect.size.height);
			visibleRect.origin.y = MAX(0, contentRectSize.height - visibleRect.size.height);
		}
	}

	// Restore original visible rectangle of scroller
	[self scrollToArea:visibleRect animate:NO];
    
    [_textFinder noteClientStringWillChange];

	self.needsDisplay = YES;
}

#pragma mark Layout Support

- (NSRect)rectOfColumn:(NSUInteger)columnIndex {
	NSRect rect = [self convertRect:[contentView rectOfColumn:columnIndex] fromView:contentView];
	rect.origin.y = 0;
	rect.size.height += columnHeaderScrollView.frame.size.height;
	if (rect.size.height > self.frame.size.height) {
		rect.size.height = self.frame.size.height;

		// If the scrollbar is visible, don't include it in the rect
        if (!contentScrollView.horizontalScroller.isHidden && contentScrollView.scrollerStyle == NSScrollerStyleLegacy) {
            rect.size.height -= [NSScroller scrollerWidthForControlSize:NSControlSizeRegular
                                                          scrollerStyle:contentScrollView.scrollerStyle];
        }
	}

	return rect;
}

- (NSRect)rectOfRow:(NSUInteger)rowIndex {
	NSRect rect = [self convertRect:[contentView rectOfRow:rowIndex] fromView:contentView];
	rect.origin.x = 0;
	rect.size.width += rowHeaderScrollView.frame.size.width;

	return rect;
}

- (NSRect)rectOfSelectionRelativeToContentView {
    NSRect dirtyRect = NSZeroRect;
    if (selectedRowIndexes.count) {
        dirtyRect = NSUnionRect([self.contentView rectOfRow:selectedRowIndexes.firstIndex],
                                [self.contentView rectOfRow:selectedRowIndexes.lastIndex]);
        if (selectedColumnIndexes.count) {
            NSRect dirtyColumnRect = NSUnionRect([self.contentView rectOfColumn:selectedColumnIndexes.firstIndex],
                                                 [self.contentView rectOfColumn:selectedColumnIndexes.lastIndex]);
            dirtyRect = NSIntersectionRect(dirtyRect, dirtyColumnRect);
        }
    } else if (selectedColumnIndexes.count) {
        dirtyRect = NSUnionRect([self.contentView rectOfColumn:selectedColumnIndexes.firstIndex],
                                [self.contentView rectOfColumn:selectedColumnIndexes.lastIndex]);
    }
    return dirtyRect;
}

- (NSRect)frameOfCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	return [self convertRect:[contentView frameOfCellAtColumn:columnIndex row:rowIndex] fromView:contentView];
}

- (NSRect)headerRectOfColumn:(NSUInteger)columnIndex {
	return [self convertRect:[columnHeaderView headerRectOfColumn:columnIndex] fromView:columnHeaderView];
}

- (NSRect)headerRectOfRow:(NSUInteger)rowIndex {
	return [self convertRect:[rowHeaderView headerRectOfColumn:rowIndex] fromView:rowHeaderView];
}

- (NSRect)headerRectOfCorner {
    return headerCornerView.frame;
}

- (NSRect)footerRectOfCorner {
    return footerCornerView.frame;
}

- (NSInteger)columnAtPoint:(NSPoint)aPoint {
	NSInteger column = 0;
	while (column < _numberOfColumns) {
		NSRect columnFrame = [self rectOfColumn:column];
		if (NSPointInRect(aPoint, columnFrame)) {
			return column;
		}
		column++;
	}
	return NSNotFound;
}

- (NSInteger)rowAtPoint:(NSPoint)aPoint {
    return [self.contentView rowAtPoint:[self convertPoint:aPoint toView:self.contentView]];
}

#pragma mark Auxiliary Views

- (MBTableGridHeaderView *)columnHeaderView {
	return columnHeaderView;
}

- (MBTableGridHeaderView *)rowHeaderView {
	return rowHeaderView;
}

- (MBTableGridContentView *)contentView {
	return contentView;
}

- (BOOL)isColumnHeaderVisible {
    return columnHeaderScrollView.frame.size.height > 0.0;
}

- (void)setColumnHeaderVisible:(BOOL)isVisible {
    [columnHeaderScrollView removeConstraints:columnHeaderScrollView.constraints];
    [NSLayoutConstraint constraintWithItem:columnHeaderScrollView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:0.0
                                  constant:isVisible ? MBTableGridColumnHeaderHeight : 0.0].active = YES;
    [self updateSubviewInsets];
}

- (BOOL)isColumnFooterVisible {
    return columnFooterScrollView.frame.size.height > 0.0;
}

- (void)setColumnFooterVisible:(BOOL)isVisible {
    [columnFooterScrollView removeConstraints:columnFooterScrollView.constraints];
    [NSLayoutConstraint constraintWithItem:columnFooterScrollView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:0.0
                                  constant:isVisible ? MBTableGridColumnFooterHeight : 0.0].active = YES;
    [self updateSubviewInsets];
}

- (BOOL)isRowHeaderVisible {
    return rowHeaderScrollView.frame.size.width > 0.0;
}

- (void)setRowHeaderVisible:(BOOL)isVisible {
    [rowHeaderScrollView removeConstraints:rowHeaderScrollView.constraints];
    [NSLayoutConstraint constraintWithItem:rowHeaderScrollView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:0.0
                                  constant:isVisible ? MBTableGridRowHeaderWidth : 0.0].active = YES;
    [self updateSubviewInsets];
}

- (void)setContentInsets:(NSEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    [self updateSubviewConstraints];
    [self updateSubviewInsets];
}

#pragma mark - Overridden Property Accessors

- (void)setSelectedColumnIndexes:(NSIndexSet *)anIndexSet {
	[self setSelectedColumnIndexes:anIndexSet notify:YES];
}

- (void)setSelectedColumnIndexes:(NSIndexSet *)anIndexSet notify:(BOOL)notify {
    if ([anIndexSet isEqualToIndexSet:selectedColumnIndexes])
		return;

	// Allow the delegate to validate the selection
	if ([self.delegate respondsToSelector:@selector(tableGrid:willSelectColumnsAtIndexPath:)]) {
		anIndexSet = [self.delegate tableGrid:self willSelectColumnsAtIndexPath:anIndexSet];
	}

    // mark old selection as dirty
    [self.contentView setNeedsDisplayInRect:[self rectOfSelectionRelativeToContentView]];

	selectedColumnIndexes = anIndexSet;

    // mark new selection as dirty
    [self.contentView setNeedsDisplayInRect:[self rectOfSelectionRelativeToContentView]];

    // mark other views as dirty
    columnHeaderView.needsDisplay = YES;
    columnFooterView.needsDisplay = YES;

	// Post the notification
	if(notify) {
		[NSNotificationCenter.defaultCenter postNotificationName:MBTableGridDidChangeSelectionNotification object:self];
	}
}

- (void)setSelectedRowIndexes:(NSIndexSet *)anIndexSet {
	[self setSelectedRowIndexes:anIndexSet notify:YES];
}

- (void)setSelectedRowIndexes:(NSIndexSet *)anIndexSet notify:(BOOL)notify {
    if ([anIndexSet isEqualToIndexSet:selectedRowIndexes])
        return;

	// Allow the delegate to validate the selection
	if ([self.delegate respondsToSelector:@selector(tableGrid:willSelectRowsAtIndexPath:)]) {
		anIndexSet = [self.delegate tableGrid:self willSelectRowsAtIndexPath:anIndexSet];
	}

    // mark old selection as dirty
    [self.contentView setNeedsDisplayInRect:[self rectOfSelectionRelativeToContentView]];

	selectedRowIndexes = anIndexSet;

    // mark new selection as dirty
    [self.contentView setNeedsDisplayInRect:[self rectOfSelectionRelativeToContentView]];

    // mark other views as dirty
    rowHeaderView.needsDisplay = YES;
	
	// Post the notification
	if(notify) {
		[NSNotificationCenter.defaultCenter postNotificationName:MBTableGridDidChangeSelectionNotification object:self];
	}
}

- (void)setDelegate:(id <MBTableGridDelegate> )anObject {
	if (anObject == delegate)
		return;

	if (delegate) {
		// Unregister the delegate for relevant notifications
		[NSNotificationCenter.defaultCenter removeObserver:delegate name:MBTableGridDidChangeSelectionNotification object:self];
		[NSNotificationCenter.defaultCenter removeObserver:delegate name:MBTableGridDidMoveColumnsNotification object:self];
		[NSNotificationCenter.defaultCenter removeObserver:delegate name:MBTableGridDidMoveRowsNotification object:self];
	}

	delegate = anObject;

	// Register the new delegate for relevant notifications
	if ([delegate respondsToSelector:@selector(tableGridDidChangeSelection:)]) {
		[NSNotificationCenter.defaultCenter addObserver:delegate selector:@selector(tableGridDidChangeSelection:) name:MBTableGridDidChangeSelectionNotification object:self];
	}
	if ([delegate respondsToSelector:@selector(tableGridDidMoveColumns:)]) {
		[NSNotificationCenter.defaultCenter addObserver:delegate selector:@selector(tableGridDidMoveColumns:) name:MBTableGridDidMoveColumnsNotification object:self];
	}
	if ([delegate respondsToSelector:@selector(tableGridDidMoveRows:)]) {
		[NSNotificationCenter.defaultCenter addObserver:delegate selector:@selector(tableGridDidMoveRows:) name:MBTableGridDidMoveRowsNotification object:self];
	}
    
    self.columnFooterVisible = [delegate respondsToSelector:@selector(tableGrid:footerCellForColumn:)];
}

@end

@implementation MBTableGrid (Drawing)

- (BOOL) opaque {
	return YES;
}

@end

@implementation MBTableGrid (DataAccessors)

- (NSString *)_headerStringForColumn:(NSUInteger)columnIndex {
	// Ask the data source
	if ([self.dataSource respondsToSelector:@selector(tableGrid:headerStringForColumn:)]) {
		return [self.dataSource tableGrid:self headerStringForColumn:columnIndex];
	}

	char alphabetChar = columnIndex + 'A';
	return [NSString stringWithFormat:@"%c", alphabetChar];
}

- (NSString *)_headerStringForRow:(NSUInteger)rowIndex {
	// Ask the data source
	if ([self.dataSource respondsToSelector:@selector(tableGrid:headerStringForRow:)]) {
		return [self.dataSource tableGrid:self headerStringForRow:rowIndex];
	}

	return [NSString stringWithFormat:@"%lu", (rowIndex + 1)];
}

// This form prefers the singular form of the setObjectValue: data source method,
// but will fall back to the plural form
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumn:row:)]) {
        [self.dataSource tableGrid:self setObjectValue:value forColumn:columnIndex row:rowIndex];
    } else if ([self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumns:rows:)]) {
        [self.dataSource tableGrid:self setObjectValue:value
                        forColumns:[NSIndexSet indexSetWithIndex:columnIndex]
                              rows:[NSIndexSet indexSetWithIndex:rowIndex]];
    }
}

// This form prefers the plural form of the setObjectValue: data source method,
// but if not implemented will fall back to the singular form (potentially very slow)
- (void)_setObjectValue:(id)value forColumns:(NSIndexSet *)columnIndexes rows:(NSIndexSet *)rowIndexes {
	if ([self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumns:rows:)]) {
		[self.dataSource tableGrid:self setObjectValue:value forColumns:columnIndexes rows:rowIndexes];
    } else if ([self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumn:row:)]) {
        [columnIndexes enumerateIndexesUsingBlock:^(NSUInteger columnIndex, BOOL *stopColumns) {
            [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL *stopRows) {
                [self.dataSource tableGrid:self setObjectValue:value forColumn:columnIndex row:rowIndex];
            }];
        }];
	}
}

- (CGFloat)_minimumWidthForColumn:(NSUInteger)columnIndex {
    CGFloat minColumnWidth = MBTableHeaderMinimumColumnWidth;
    
    if ([columnHeaderView.indicatorImageColumns containsIndex:columnIndex]) {
        minColumnWidth += MBTableHeaderSortIndicatorWidth + MBTableHeaderSortIndicatorMargin;
    }
    
    return minColumnWidth;
}

- (CGFloat)_widthForColumn:(NSUInteger)columnIndex {
    if (columnIndex >= _numberOfColumns)
        return 0.0;
    
    CGFloat width = 0.0;
    CGFloat min_width = [self _minimumWidthForColumn:columnIndex];
    
    if ([self.dataSource respondsToSelector:@selector(tableGrid:widthForColumn:)]) {
        width = [self.dataSource tableGrid:self widthForColumn:columnIndex];
        if (width > min_width) {
            _columnWidths[@(columnIndex)] = @(width);
        }
    }
    
    if (_columnWidths[@(columnIndex)]) {
        return _columnWidths[@(columnIndex)].doubleValue;
    }

    return min_width;
}

- (void)_setWidth:(CGFloat)width forColumn:(NSUInteger)columnIndex
{
    _columnWidths[@(columnIndex)] = @(width);
	
	if ([self.dataSource respondsToSelector:@selector(tableGrid:setWidth:forColumn:)]) {
		[self.dataSource tableGrid:self setWidth:width forColumn:columnIndex];
    }
}

- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex {
	// Can't edit if the data source doesn't implement the method
	if (![self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumn:row:)] &&
        ![self.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumns:rows:)]) {
		return NO;
	}

	// Ask the delegate if the cell is editable
	if ([self.delegate respondsToSelector:@selector(tableGrid:shouldEditColumn:row:)]) {
		return [self.delegate tableGrid:self shouldEditColumn:columnIndex row:rowIndex];
	}

	return YES;
}

#pragma mark Footer

- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:footerCellForColumn:)]) {
        return [self.dataSource tableGrid:self footerCellForColumn:columnIndex];
    }
    return nil;
}

- (id)_footerValueForColumn:(NSUInteger)columnIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:footerValueForColumn:)]) {
        id value = [self.dataSource tableGrid:self footerValueForColumn:columnIndex];
        return value;
    }
    return nil;
}

- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex {
    if ([self.dataSource respondsToSelector:@selector(tableGrid:setFooterValue:forColumn:)]) {
        [self.dataSource tableGrid:self setFooterValue:value forColumn:columnIndex];
    }
}

@end

@implementation MBTableGrid (DoubleClick)

- (void)_didDoubleClickColumn:(NSUInteger)columnIndex {
    if ([self.delegate respondsToSelector:@selector(tableGrid:didDoubleClickColumn:)])
        [self.delegate tableGrid:self didDoubleClickColumn:columnIndex];
}

- (void)_didDoubleClickRow:(NSUInteger)rowIndex {
    if ([self.delegate respondsToSelector:@selector(tableGrid:didDoubleClickRow:)])
        [self.delegate tableGrid:self didDoubleClickRow:rowIndex];
}

@end

@implementation MBTableGrid (PrivateAccessors)

- (MBTableGridContentView *)_contentView {
	return contentView;
}

- (void)_setStickyColumn:(MBHorizontalEdge)stickyColumn row:(MBVerticalEdge)stickyRow {
	stickyColumnEdge = stickyColumn;
	stickyRowEdge = stickyRow;
}

- (MBHorizontalEdge)_stickyColumn {
	return stickyColumnEdge;
}

- (MBVerticalEdge)_stickyRow {
	return stickyRowEdge;
}

@end

@implementation MBTableGrid (DragAndDrop)

- (void)_dragColumnsWithEvent:(NSEvent *)theEvent {
	NSImage *dragImage = [self _imageForSelectedColumns];

	NSRect firstSelectedColumn = [self rectOfColumn:self.selectedColumnIndexes.firstIndex];
	NSPoint location = firstSelectedColumn.origin;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.selectedColumnIndexes];
    NSPasteboardItem *pbItem = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:data ofType:MBTableGridColumnDataType];
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
    
    NSRect dragImageFrame = NSMakeRect(location.x, location.y, dragImage.size.width, dragImage.size.height);
    [item setDraggingFrame:dragImageFrame contents:dragImage];
    id source = (id <NSDraggingSource>) self;

    [self beginDraggingSessionWithItems:@[item] event:theEvent source:source];
}

- (void)_dragRowsWithEvent:(NSEvent *)theEvent {
	NSImage *dragImage = [self _imageForSelectedRows];
    
	NSRect firstSelectedRow = [self rectOfRow:self.selectedRowIndexes.firstIndex];
	NSPoint location = firstSelectedRow.origin;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.selectedRowIndexes];
    NSPasteboardItem *pbItem = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:data ofType:MBTableGridRowDataType];
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
    
    NSRect dragImageFrame = NSMakeRect(location.x, location.y, dragImage.size.width, dragImage.size.height);
    [item setDraggingFrame:dragImageFrame contents:dragImage];
    id source = (id <NSDraggingSource>) self;
    
    [self beginDraggingSessionWithItems:@[item] event:theEvent source:source];
}

- (NSImage *)_imageForSelectedColumns {
	NSRect firstColumnFrame = [self rectOfColumn:self.selectedColumnIndexes.firstIndex];
	NSRect lastColumnFrame = [self rectOfColumn:self.selectedColumnIndexes.lastIndex];
    NSRect columnsFrame = NSUnionRect(firstColumnFrame, lastColumnFrame);
	// Extend the frame to show the left border
	columnsFrame.origin.x -= 1.0;
	columnsFrame.size.width += 1.0;

	// Take a snapshot of the view
	NSImage *opaqueImage = [[NSImage alloc] initWithData:[self dataWithPDFInsideRect:columnsFrame]];

	// Create the translucent drag image
	NSImage *finalImage = [[NSImage alloc] initWithSize:opaqueImage.size];
	[finalImage lockFocus];
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_8
	[opaqueImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
#else
    [opaqueImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:0.7];
#endif
	[finalImage unlockFocus];

	return finalImage;
}

- (NSImage *)_imageForSelectedRows {
	NSRect firstRowFrame = [self rectOfRow:self.selectedRowIndexes.firstIndex];
	NSRect lastRowFrame = [self rectOfRow:self.selectedRowIndexes.lastIndex];
    NSRect rowsFrame = NSUnionRect(firstRowFrame, lastRowFrame);
	// Extend the frame to show the top border
	rowsFrame.origin.y -= 1.0;
	rowsFrame.size.height += 1.0;

	// Take a snapshot of the view
	NSImage *opaqueImage = [[NSImage alloc] initWithData:[self dataWithPDFInsideRect:rowsFrame]];

	// Create the translucent drag image
	NSImage *finalImage = [[NSImage alloc] initWithSize:opaqueImage.size];
	[finalImage lockFocus];
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_8
	[opaqueImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
#else
    [opaqueImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:0.7];
#endif
	[finalImage unlockFocus];

	return finalImage;
}

- (NSUInteger)_dropColumnForPoint:(NSPoint)aPoint {
	NSUInteger column = [self columnAtPoint:aPoint];

	if (column == NSNotFound) {
		return NSNotFound;
	}

	// If we're in the right half of the column, we intent to drop on the right side
	NSRect columnFrame = [self rectOfColumn:column];
	columnFrame.size.width /= 2;
	if (!NSPointInRect(aPoint, columnFrame)) {
		column++;
	}

	return column;
}

- (NSUInteger)_dropRowForPoint:(NSPoint)aPoint {
	NSUInteger row = [self rowAtPoint:aPoint];

	if (row == NSNotFound) {
		return NSNotFound;
	}

	// If we're in the bottom half of the row, we intent to drop on the bottom side
	NSRect rowFrame = [self rectOfRow:row];
	rowFrame.size.height /= 2;

	if (!NSPointInRect(aPoint, rowFrame)) {
		row++;
	}

	return row;
}

@end

@implementation MBTableGrid (HeaderMenus)

- (void)_willDisplayHeaderMenu:(NSMenu *)menu forColumn:(NSUInteger)columnIndex {
    if ([self.delegate respondsToSelector:@selector(tableGrid:willDisplayHeaderMenu:forColumn:)])
        [self.delegate tableGrid:self willDisplayHeaderMenu:menu forColumn:columnIndex];
}

- (void)_willDisplayHeaderMenu:(NSMenu *)menu forRow:(NSUInteger)rowIndex {
    if ([self.delegate respondsToSelector:@selector(tableGrid:willDisplayHeaderMenu:forRow:)])
        [self.delegate tableGrid:self willDisplayHeaderMenu:menu forRow:rowIndex];
}

@end
