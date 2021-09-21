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

#import "MBTableGridContentView.h"

#import "MBTableGrid.h"
#import "MBTableGridCell.h"
#import "MBTableGridEditable.h"
#import "NSScrollView+InsetRectangles.h"

#define kGRAB_HANDLE_HALF_SIDE_LENGTH 3.0f
#define kGRAB_HANDLE_SIDE_LENGTH 6.0f
#define DROP_TARGET_BOX_THICKNESS 4.0
#define DROP_TARGET_LINE_WIDTH    2.0

NSString * const MBTableGridTrackingPartKey = @"part";

@interface MBTableGrid (Private)
@property (nonatomic, readonly) MBHorizontalEdge _stickyColumn;
@property (nonatomic, readonly) MBVerticalEdge _stickyRow;
@property (nonatomic, readonly) NSColor *_selectionColor;
@property (nonatomic, readonly) BOOL _containsFirstResponder;

- (NSCell *)_cellForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumns:(NSIndexSet *)columnIndexes rows:(NSIndexSet *)rowIndexes;
- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setStickyColumn:(MBHorizontalEdge)stickyColumn row:(MBVerticalEdge)stickyRow;
- (CGFloat)_widthForColumn:(NSUInteger)columnIndex;
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (void)_didDoubleClickColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSRange)_rangeOfRowsIntersectingRect:(NSRect)rect;
- (NSRange)_rangeOfColumnsIntersectingRect:(NSRect)rect;
@end

@interface MBTableGridContentView (Cursors)
@property (nonatomic, copy, readonly) NSCursor *_cellSelectionCursor;
@property (nonatomic, copy, readonly) NSImage *_cellSelectionCursorImage;
@property (nonatomic, copy, readonly) NSCursor *_cellExtendSelectionCursor;
@property (nonatomic, copy, readonly) NSImage *_cellExtendSelectionCursorImage;
@property (nonatomic, copy, readonly) NSImage *_grabHandleImage;
@end

@interface MBTableGridContentView (DragAndDrop)
- (void)_setDraggingColumnOrRow:(BOOL)flag;
- (void)_setDropColumn:(NSInteger)columnIndex;
- (void)_setDropRow:(NSInteger)rowIndex;
- (void)_timerAutoscrollCallback:(NSTimer *)aTimer;
@end

@implementation MBTableGridContentView

@synthesize showsGrabHandle;
@synthesize rowHeight = _rowHeight;

#pragma mark -
#pragma mark Initialization & Superclass Overrides

- (instancetype)initWithFrame:(NSRect)frameRect andTableGrid:(MBTableGrid*)tableGrid
{
	if(self = [super initWithFrame:frameRect]) {
		
		_tableGrid = tableGrid;
		
		showsGrabHandle = NO;
		mouseDownColumn = NSNotFound;
		mouseDownRow = NSNotFound;
		
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		dropColumn = NSNotFound;
		dropRow = NSNotFound;
        
		grabHandleImage = [self _grabHandleImage];
        grabHandleRect = NSZeroRect;
		
		// Cache the cursor image
		cursorImage = self._cellSelectionCursorImage;
        cursorExtendSelectionImage = self._cellExtendSelectionCursorImage;
		
        isCompleting = NO;
		isDraggingColumnOrRow = NO;
        shouldDrawFillPart = MBTableGridTrackingPartNone;

		_rowHeight = 20.0;
		
		_defaultCell = [[MBTableGridCell alloc] initTextCell:@""];
        _defaultCell.bordered = YES;
        _defaultCell.scrollable = YES;
        _defaultCell.lineBreakMode = NSLineBreakByTruncatingTail;
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)drawCellInteriorsInRect:(NSRect)rect {
    NSRange columnRange = [_tableGrid _rangeOfColumnsIntersectingRect:[self convertRect:rect toView:_tableGrid]];
    NSRange rowRange = [_tableGrid _rangeOfRowsIntersectingRect:[self convertRect:rect toView:_tableGrid]];
    
    NSUInteger column = columnRange.location;
    while (column != NSNotFound && column < NSMaxRange(columnRange)) {
        NSUInteger row = rowRange.location;
        while (row != NSNotFound && row < NSMaxRange(rowRange)) {
            NSRect cellFrame = [self frameOfCellAtColumn:column row:row];
            if ([self needsToDrawRect:cellFrame] && (!(row == editedRow && column == editedColumn))) {
                // Only fetch the cell if we need to
                NSCell* cell = [_tableGrid _cellForColumn:column row: row];
                [cell drawWithFrame:cellFrame inView:self];
            }
            row++;
        }
        column++;
    }
}

- (void)drawColumnDropIndicator {
    // Draw the column drop indicator
    if (isDraggingColumnOrRow && dropColumn != NSNotFound && dropColumn <= _tableGrid.numberOfColumns && dropRow == NSNotFound) {
        NSRect columnBorder;
        if(dropColumn < _tableGrid.numberOfColumns) {
            columnBorder = [self rectOfColumn:dropColumn];
        } else {
            columnBorder = [self rectOfColumn:dropColumn-1];
            columnBorder.origin.x += columnBorder.size.width;
        }
        columnBorder.origin.x = NSMinX(columnBorder)-DROP_TARGET_BOX_THICKNESS/2;
        columnBorder.size.width = DROP_TARGET_BOX_THICKNESS;
        
        NSColor *selectionColor = NSColor.alternateSelectedControlColor;
        
        NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:columnBorder];
        borderPath.lineWidth = DROP_TARGET_LINE_WIDTH;
        
        [selectionColor set];
        [borderPath stroke];
    }
}

- (void)drawRowDropIndicator {
    // Draw the row drop indicator
    if (isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= _tableGrid.numberOfRows && dropColumn == NSNotFound) {
        NSRect rowBorder;
        if(dropRow < _tableGrid.numberOfRows) {
            rowBorder = [self rectOfRow:dropRow];
        } else {
            rowBorder = [self rectOfRow:dropRow-1];
            rowBorder.origin.y += rowBorder.size.height;
        }
        rowBorder.origin.y = NSMinY(rowBorder)-DROP_TARGET_BOX_THICKNESS/2;
        rowBorder.size.height = DROP_TARGET_BOX_THICKNESS;
        
        NSColor *selectionColor = NSColor.alternateSelectedControlColor;
        
        NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:rowBorder];
        borderPath.lineWidth = DROP_TARGET_LINE_WIDTH;
        
        [selectionColor set];
        [borderPath stroke];
    }
}

- (void)drawCellDropIndicator {
    // Draw the cell drop indicator
    if (!isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= _tableGrid.numberOfRows && dropColumn != NSNotFound && dropColumn <= _tableGrid.numberOfColumns) {
        NSRect cellFrame = [self frameOfCellAtColumn:dropColumn row:dropRow];
        cellFrame.origin.x -= 2.0;
        cellFrame.origin.y -= 2.0;
        cellFrame.size.width += 3.0;
        cellFrame.size.height += 3.0;
        
        NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:NSInsetRect(cellFrame, 2, 2)];
        
        NSColor *dropColor = NSColor.alternateSelectedControlColor;
        [dropColor set];
        
        borderPath.lineWidth = 2.0;
        [borderPath stroke];
    }
}

- (void)drawRect:(NSRect)rect
{
    NSIndexSet *selectedColumns = _tableGrid.selectedColumnIndexes;
    NSIndexSet *selectedRows = _tableGrid.selectedRowIndexes;
	NSUInteger numberOfColumns = _tableGrid.numberOfColumns;
	NSUInteger numberOfRows = _tableGrid.numberOfRows;
    
    if (numberOfColumns == 0 || numberOfRows == 0)
        return;
    
    NSBezierPath *selectionPath = nil;
    NSColor *selectionColor = _tableGrid._selectionColor;
    BOOL disabled = !_tableGrid._containsFirstResponder;
    NSRect selectionInsetRect = NSZeroRect;
    
    if (isFilling && !disabled) {
        selectionColor = NSColor.systemYellowColor;
    }
    
	// Determine the selection rectangle
    if(selectedColumns.count && selectedRows.count) {
		NSRect selectionTopLeft = [self frameOfCellAtColumn:selectedColumns.firstIndex row:selectedRows.firstIndex];
		NSRect selectionBottomRight = [self frameOfCellAtColumn:selectedColumns.lastIndex row:selectedRows.lastIndex];
		
        NSRect selectionRect = NSUnionRect(selectionTopLeft, selectionBottomRight);
        selectionInsetRect = NSInsetRect(selectionRect, 0, 0);
        selectionPath = [NSBezierPath bezierPathWithRect:selectionInsetRect];
        NSAffineTransform *translate = [NSAffineTransform transform];
        [translate translateXBy:-0.5 yBy:-0.5];
        [selectionPath transformUsingAffineTransform:translate];
    }
    
    // Fill the selection rectangle
    if (selectionPath) {
        [[selectionColor colorWithAlphaComponent:0.2] set];
        [selectionPath fill];
    }
    
    [self drawCellInteriorsInRect:rect];

    // Draw the selection borders and grab handle art
    if (selectionPath) {
        [NSGraphicsContext.currentContext saveGraphicsState];
        [selectionPath addClip];
        
        [[selectionColor colorWithAlphaComponent:0.3] set];
        selectionPath.lineWidth = 2.0;
        [selectionPath stroke];
        
        [NSGraphicsContext.currentContext restoreGraphicsState];

		if (!showsGrabHandle || disabled || selectedColumns.count > 1) {
			grabHandleRect = NSZeroRect;
		}
        else if (shouldDrawFillPart != MBTableGridTrackingPartNone) {
            // Draw grab handle
            grabHandleRect = NSMakeRect(NSMidX(selectionInsetRect) - kGRAB_HANDLE_HALF_SIDE_LENGTH - 2, (shouldDrawFillPart == MBTableGridTrackingPartFillTop ? NSMinY(selectionInsetRect) : NSMaxY(selectionInsetRect)) - kGRAB_HANDLE_HALF_SIDE_LENGTH - 2, kGRAB_HANDLE_SIDE_LENGTH + 4, kGRAB_HANDLE_SIDE_LENGTH + 4);
            [grabHandleImage drawInRect:grabHandleRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        }
		
        // Inavlidate cursors so we use the correct cursor for the selection in the right place
        [self.window invalidateCursorRectsForView:self];
	}
    
    [self drawColumnDropIndicator];
    [self drawRowDropIndicator];
    [self drawCellDropIndicator];
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)startAutoscrollTimer {
    // Setup the timer for autoscrolling
    // (the simply calling autoscroll: from mouseDragged: only works as long as the mouse is moving)
    if (!autoscrollTimer)
        autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self
                                                         selector:@selector(_timerAutoscrollCallback:)
                                                         userInfo:nil repeats:NO];
}

- (void)stopAutoscrollTimer {
    [autoscrollTimer invalidate];
    autoscrollTimer = nil;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    if (!self.tableGrid.acceptsFirstResponder)
        return;
        
	NSPoint mouseLocationInContentView = [self convertPoint:theEvent.locationInWindow fromView:nil];
	mouseDownColumn = [self columnAtPoint:mouseLocationInContentView];
	mouseDownRow = [self rowAtPoint:mouseLocationInContentView];

	if (mouseDownRow == NSNotFound || mouseDownColumn == NSNotFound) {
		return;
	}
    
    [self startAutoscrollTimer];
    
	NSCell *cell = [self.tableGrid _cellForColumn:mouseDownColumn row: mouseDownRow];
	BOOL cellEditsOnFirstClick = [cell respondsToSelector:@selector(editOnFirstClick)] ? ([(id<MBTableGridEditable>)cell editOnFirstClick]==YES) : self.tableGrid.singleClickCellEdit;
    isFilling = NO;
    
	if (theEvent.clickCount == 1) {
		// Pass the event back to the MBTableGrid (Used to give First Responder status)
		[self.tableGrid mouseDown:theEvent];
		
		NSUInteger selectedColumn = self.tableGrid.selectedColumnIndexes.firstIndex;
		NSUInteger selectedRow = self.tableGrid.selectedRowIndexes.firstIndex;

        isFilling = showsGrabHandle && NSPointInRect(mouseLocationInContentView, grabHandleRect);
        
        if (isFilling) {
            numberOfRowsWhenStartingFilling = self.tableGrid.numberOfRows;
            
            if (mouseDownRow == selectedRow - 1 || mouseDownRow == selectedRow + 1) {
                mouseDownRow = selectedRow;
            }
        }
        
		// Edit an already selected cell if it doesn't edit on first click
		if (selectedColumn == mouseDownColumn && selectedRow == mouseDownRow && !cellEditsOnFirstClick && !isFilling) {
			[self editSelectedCell:self text:nil];

		// Expand a selection when the user holds the shift key
        } else if ((theEvent.modifierFlags & NSEventModifierFlagShift) && self.tableGrid.allowsMultipleSelection && !isFilling) {
			// If the shift key was held down, extend the selection
			NSUInteger stickyColumn = self.tableGrid.selectedColumnIndexes.firstIndex;
			NSUInteger stickyRow = self.tableGrid.selectedRowIndexes.firstIndex;

			MBHorizontalEdge stickyColumnEdge = [self.tableGrid _stickyColumn];
			MBVerticalEdge stickyRowEdge = [self.tableGrid _stickyRow];
			
			// Compensate for sticky edges
			if (stickyColumnEdge == MBHorizontalEdgeRight) {
				stickyColumn = self.tableGrid.selectedColumnIndexes.lastIndex;
			}
			if (stickyRowEdge == MBVerticalEdgeBottom) {
				stickyRow = self.tableGrid.selectedRowIndexes.lastIndex;
			}
			
			NSRange selectionColumnRange = NSMakeRange(stickyColumn, mouseDownColumn-stickyColumn+1);
			NSRange selectionRowRange = NSMakeRange(stickyRow, mouseDownRow-stickyRow+1);
			
			if (mouseDownColumn < stickyColumn) {
				selectionColumnRange = NSMakeRange(mouseDownColumn, stickyColumn-mouseDownColumn+1);
				stickyColumnEdge = MBHorizontalEdgeRight;
			} else {
				stickyColumnEdge = MBHorizontalEdgeLeft;
			}
			
			if (mouseDownRow < stickyRow) {
				selectionRowRange = NSMakeRange(mouseDownRow, stickyRow-mouseDownRow+1);
				stickyRowEdge = MBVerticalEdgeBottom;
			} else {
				stickyRowEdge = MBVerticalEdgeTop;
			}
			
			// Select the proper cells
			self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionColumnRange];
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionRowRange];
			
			// Set the sticky edges
			[self.tableGrid _setStickyColumn:stickyColumnEdge row:stickyRowEdge];
		// First click on a cell without shift key modifier
		} else {
			// No modifier keys, so change the selection
            self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:mouseDownColumn];
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:mouseDownRow];
			[self.tableGrid _setStickyColumn:MBHorizontalEdgeLeft row:MBVerticalEdgeTop];
		}
    // Edit cells on double click if they don't already edit on first click
    } else if (theEvent.clickCount == 2) {
        [self.tableGrid _didDoubleClickColumn:mouseDownColumn row:mouseDownRow];
    }

	// Any cells that should edit on first click are handled here
	if (cellEditsOnFirstClick) {
		[self editSelectedCell:self text:nil];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if (mouseDownColumn != NSNotFound && mouseDownRow != NSNotFound && self.tableGrid.allowsMultipleSelection) {
		NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
		NSInteger column = [self columnAtPoint:loc];
		NSInteger row = [self rowAtPoint:loc];
        NSInteger numberOfRows = self.tableGrid.numberOfRows;
        
        // While filling, if dragging beyond the size of the table, add more rows
        if (isFilling && loc.y > 0.0 && row == NSNotFound && [self.tableGrid.dataSource respondsToSelector:@selector(tableGrid:addRows:)]) {
            NSRect rowRect = [self rectOfRow:numberOfRows];
            NSInteger numberOfRowsToAdd = ((loc.y - rowRect.origin.y) / rowRect.size.height) + 1;
            
            if (numberOfRowsToAdd > 0 && [self.tableGrid.dataSource tableGrid:self.tableGrid addRows:numberOfRowsToAdd]) {
                row = [self rowAtPoint:loc];
            }
            
            [self.window invalidateCursorRectsForView:self];
        }
        
        // While filling, if dragging upwards, remove any rows added during the fill operation
        if (isFilling && row < numberOfRows && [self.tableGrid.dataSource respondsToSelector:@selector(tableGrid:removeRows:)]) {
            NSInteger firstRowToRemove = row + 1;
            
            if (firstRowToRemove < numberOfRowsWhenStartingFilling) {
                firstRowToRemove = numberOfRowsWhenStartingFilling;
            }
            
            NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRowToRemove, numberOfRows - firstRowToRemove)];
            
            [self.tableGrid.dataSource tableGrid:self.tableGrid removeRows:rowIndexes];
            
            [self.window invalidateCursorRectsForView:self];
        }
		
		MBHorizontalEdge columnEdge = MBHorizontalEdgeLeft;
		MBVerticalEdge rowEdge = MBVerticalEdgeTop;
		
		// Select the appropriate number of columns
		if(column != NSNotFound && !isFilling) {
			NSInteger firstColumnToSelect = mouseDownColumn;
			NSInteger numberOfColumnsToSelect = column-mouseDownColumn+1;
			if(column < mouseDownColumn) {
				firstColumnToSelect = column;
				numberOfColumnsToSelect = mouseDownColumn-column+1;

				columnEdge = MBHorizontalEdgeRight;
			}
			
			self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumnToSelect,numberOfColumnsToSelect)];
		}
		
		// Select the appropriate number of rows
		if(row != NSNotFound) {
			NSInteger firstRowToSelect = mouseDownRow;
			NSInteger numberOfRowsToSelect = row-mouseDownRow+1;
			if(row < mouseDownRow) {
				firstRowToSelect = row;
				numberOfRowsToSelect = mouseDownRow-row+1;

				rowEdge = MBVerticalEdgeBottom;
			}
			
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRowToSelect,numberOfRowsToSelect)];
		}
		
		// Set the sticky edges
		[self.tableGrid _setStickyColumn:columnEdge row:rowEdge];
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
    [self stopAutoscrollTimer];
	
	if (isFilling) {
		id value = [self.tableGrid _objectValueForColumn:mouseDownColumn row:mouseDownRow];
		
        [self.tableGrid _setObjectValue:[value copy]
                             forColumns:[NSIndexSet indexSetWithIndex:mouseDownColumn]
                                   rows:self.tableGrid.selectedRowIndexes];
		
        NSInteger numberOfRows = self.tableGrid.numberOfRows;
        
        // If rows were added, tell the delegate
        if (isFilling && numberOfRows > numberOfRowsWhenStartingFilling && [self.tableGrid.delegate respondsToSelector:@selector(tableGrid:didAddRows:)]) {
            NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(numberOfRowsWhenStartingFilling, numberOfRows - numberOfRowsWhenStartingFilling)];
            
            [self.tableGrid.delegate tableGrid:self.tableGrid didAddRows:rowIndexes];
        }
        
		isFilling = NO;
        
        self.tableGrid.needsDisplay = YES;
	}
	
	mouseDownColumn = NSNotFound;
	mouseDownRow = NSNotFound;
    [self.window invalidateCursorRectsForView:self];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    NSDictionary<NSString *, id> *dict = theEvent.userData;
    MBTableGridTrackingPart part = [dict[MBTableGridTrackingPartKey] integerValue];
    
    if (shouldDrawFillPart != part) {
        shouldDrawFillPart = part;
        self.needsDisplay = YES;
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    if (shouldDrawFillPart != MBTableGridTrackingPartNone) {
        shouldDrawFillPart = MBTableGridTrackingPartNone;
		self.needsDisplay = YES;
    }
}

#pragma mark Cursor Rects

- (void) updateTrackingAreas {
	NSIndexSet *selectedColumns = self.tableGrid.selectedColumnIndexes;
	NSIndexSet *selectedRows = self.tableGrid.selectedRowIndexes;

	if (selectedColumns.count > 0 && selectedRows.count > 0) {
		NSRect selectionTopLeft = [self frameOfCellAtColumn:selectedColumns.firstIndex row:selectedRows.firstIndex];
        NSRect selectionBottomRight = [self frameOfCellAtColumn:selectedColumns.lastIndex row:selectedRows.lastIndex];

        NSRect selectionRect = NSUnionRect(selectionTopLeft, selectionBottomRight);
        
		// Update tracking areas here, to leverage the selection variables
		for (NSTrackingArea *trackingArea in self.trackingAreas) {
			[self removeTrackingArea:trackingArea];
		}

		if (selectedColumns.count == 1 && CGRectIntersectsRect(self.visibleRect, selectionRect)) {
            selectionRect = CGRectIntersection(selectionRect, self.visibleRect);

			NSRect fillTrackingRect = [self rectOfColumn:selectedColumns.firstIndex];
			fillTrackingRect = CGRectIntersection(fillTrackingRect, self.visibleRect);
			fillTrackingRect.size.height = self.frame.size.height;
			NSRect topFillTrackingRect, bottomFillTrackingRect;

			NSDivideRect(fillTrackingRect, &topFillTrackingRect, &bottomFillTrackingRect, selectionRect.origin.y + (selectionRect.size.height / 2.0), NSRectEdgeMinY);

			if(CGRectIntersectsRect(topFillTrackingRect, self.visibleRect)) {
				topFillTrackingRect = CGRectIntersection(topFillTrackingRect, self.visibleRect);
				[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:topFillTrackingRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:@{MBTableGridTrackingPartKey : @(MBTableGridTrackingPartFillTop)}]];
			}

			if(CGRectIntersectsRect(bottomFillTrackingRect, self.visibleRect)) {
				bottomFillTrackingRect = CGRectIntersection(bottomFillTrackingRect, self.visibleRect);
				[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:bottomFillTrackingRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:@{MBTableGridTrackingPartKey : @(MBTableGridTrackingPartFillBottom)}]];
			}
		}
	}
	[super updateTrackingAreas];
}

- (void)resetCursorRects {
    NSRect visibleRect = NSIntersectionRect(self.enclosingScrollView.insetDocumentVisibleRect, self.visibleRect);
    if (self.tableGrid.acceptsFirstResponder)
        [self addCursorRect:visibleRect cursor:self._cellSelectionCursor];
    
    [self resetToolTips];
}

- (void)resetToolTips {
    NSRect visibleRect = NSIntersectionRect(self.enclosingScrollView.insetDocumentVisibleRect, self.visibleRect);

    [self removeAllToolTips];
    NSRange columnRange = [_tableGrid _rangeOfColumnsIntersectingRect:[self convertRect:visibleRect toView:_tableGrid]];
    NSRange rowRange = [_tableGrid _rangeOfRowsIntersectingRect:[self convertRect:visibleRect toView:_tableGrid]];
    
    NSUInteger column = columnRange.location;
    while (column != NSNotFound && column < NSMaxRange(columnRange)) {
        NSUInteger row = rowRange.location;
        while (row != NSNotFound && row < NSMaxRange(rowRange)) {
            NSRect cellFrame = [self frameOfCellAtColumn:column row:row];
            // Only fetch the cell if we need to
            NSCell* cell = [_tableGrid _cellForColumn:column row: row];
            if (cell.cellSize.width > [cell titleRectForBounds:cellFrame].size.width) {
                [self addToolTipRect:[cell titleRectForBounds:cellFrame] owner:self userData:nil];
            }
            row++;
        }
        column++;
    }
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data {
    return [self.tableGrid _objectValueForColumn:[self columnAtPoint:point]
                                             row:[self rowAtPoint:point]];
}

#pragma mark -
#pragma mark Notifications

#pragma mark Field Editor

- (void)textDidBeginEditingWithEditor:(NSText *)editor
{
    isAutoEditing = YES;
}

- (void)textDidBeginEditing:(NSNotification *)notification
{
    isAutoEditing = NO;
}

- (void)textDidChange:(NSNotification *)notification
{
    isAutoEditing = NO;
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
    isAutoEditing = NO;
	NSInteger movementType = [aNotification.userInfo[@"NSTextMovement"] integerValue];

	// Give focus back to the table grid (the field editor took it)
	[self.window makeFirstResponder:self.tableGrid];

	if(movementType != NSTextMovementCancel) {
        NSString *stringValue = [((NSText *)aNotification.object).string copy];
		[self.tableGrid _setObjectValue:stringValue forColumn:editedColumn row:editedRow];
	}

	editedColumn = NSNotFound;
	editedRow = NSNotFound;
	
	// End the editing session
	NSText* fe = [self.window fieldEditor:NO forObject:self];
	[self.tableGrid.cell endEditing:fe];

	switch (movementType) {
		case NSTextMovementBacktab:
			[self.tableGrid moveLeft:self];
			break;

		case NSTextMovementTab:
			[self.tableGrid moveRight:self];
			break;

		case NSTextMovementReturn:
            if(NSApp.currentEvent.modifierFlags & NSEventModifierFlagShift) {
				[self.tableGrid moveUp:self];
			}
			else {
				[self.tableGrid moveDown:self];
			}
			break;

		case NSTextMovementUp:
			[self.tableGrid moveUp:self];
			break;

		default:
			break;
	}

	fe.alignment = NSTextAlignmentNatural;
	[self.window endEditingFor:self];
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark NSDraggingDestination

/*
 * These methods simply pass the drag event back to the table grid.
 * They are only required for autoscrolling.
 */

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    [self startAutoscrollTimer];
	return [self.tableGrid draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    [self stopAutoscrollTimer];
	[self.tableGrid draggingExited:sender];
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
	[self.tableGrid draggingEnded:sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid performDragOperation:sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[self.tableGrid concludeDragOperation:sender];
}

#pragma mark -
#pragma mark Subclass Methods

/*
- (MBTableGrid *)tableGrid
{
	return (MBTableGrid *)[[self enclosingScrollView] superview];
}
*/

- (void)editSelectedCell:(id)sender text:(NSString *)aString
{
	NSInteger selectedColumn = self.tableGrid.selectedColumnIndexes.firstIndex;
	NSInteger selectedRow = self.tableGrid.selectedRowIndexes.firstIndex;
	NSCell *selectedCell = [self.tableGrid _cellForColumn:selectedColumn row: selectedRow];

	// Check if the cell can be edited
	if(![self.tableGrid _canEditCellAtColumn:selectedColumn row:selectedColumn]) {
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		return;
	}

	// Select it and only it
	if (self.tableGrid.selectedColumnIndexes.count > 1 && editedColumn != NSNotFound) {
		self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:editedColumn];
	}
	if (self.tableGrid.selectedRowIndexes.count > 1 && editedRow != NSNotFound) {
		self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:editedRow];
	}

	// Get the top-left selection
	editedColumn = selectedColumn;
	editedRow = selectedRow;

	NSRect cellFrame = [self frameOfCellAtColumn:editedColumn row:editedRow];

	selectedCell.editable = YES;
	selectedCell.selectable = YES;
	
	NSString *currentValue = [self.tableGrid _objectValueForColumn:editedColumn row:editedRow];

	NSText *editor = [self.window fieldEditor:YES forObject:self];
	editor.delegate = self;
	editor.alignment = selectedCell.alignment;
	editor.font = selectedCell.font;
    if ([selectedCell isKindOfClass:[NSTextFieldCell class]])
        ((NSTextFieldCell *)selectedCell).textColor = NSColor.controlTextColor;
	selectedCell.stringValue = currentValue;
	editor.string = currentValue;
	NSEvent* event = NSApp.currentEvent;
    if(event != nil && event.type == NSEventTypeLeftMouseDown) {
		[selectedCell editWithFrame:cellFrame inView:self editor:editor delegate:self event:event];
	}
	else {
        [selectedCell selectWithFrame:cellFrame inView:self editor:editor delegate:self start:0 length:currentValue.length];
	}
}

#pragma mark Layout Support

- (NSRect)rectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = NSZeroRect;
	BOOL foundRect = NO;
	if (columnIndex < self.tableGrid.numberOfColumns) {
		NSValue *cachedRectValue = self.tableGrid.columnRects[@(columnIndex)];
		if (cachedRectValue) {
			rect = cachedRectValue.rectValue;
			foundRect = YES;
		}
	
		if (!foundRect) {
			CGFloat width = [self.tableGrid _widthForColumn:columnIndex];
			
			rect = NSMakeRect(0, 0, width, self.frame.size.height);
            
            if (columnIndex > 0) {
                NSRect previousRect = [self rectOfColumn:columnIndex-1];
                rect.origin.x = previousRect.origin.x + previousRect.size.width;
            }

			self.tableGrid.columnRects[@(columnIndex)] = @(rect);

		}
	}
	
    return NSMakeRect(rect.origin.x, 0.0, rect.size.width, [self frame].size.height);
}

- (NSRect)rectOfRow:(NSUInteger)rowIndex
{
	NSRect rect = NSMakeRect(0, 0, self.frame.size.width, self.rowHeight);
	rect.origin.y += self.rowHeight * rowIndex;
	return rect;
}

- (NSRect)frameOfCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex
{
	NSRect columnRect = [self rectOfColumn:columnIndex];
	NSRect rowRect = [self rectOfRow:rowIndex];
	return NSMakeRect(columnRect.origin.x, rowRect.origin.y, columnRect.size.width, rowRect.size.height);
}

- (NSInteger)columnAtPoint:(NSPoint)aPoint
{
	NSInteger column = 0;
	while(column < self.tableGrid.numberOfColumns) {
		NSRect columnFrame = [self rectOfColumn:column];
        if(aPoint.x >= NSMinX(columnFrame) && aPoint.x < NSMaxX(columnFrame)) {
			return column;
		}
		column++;
	}
	return NSNotFound;
}

- (NSInteger)rowAtPoint:(NSPoint)aPoint
{
	NSInteger row = aPoint.y / self.rowHeight;
	if(row >= 0 && row < self.tableGrid.numberOfRows) {
		return row;
	}
	return NSNotFound;
}

@end

@implementation MBTableGridContentView (Cursors)

- (NSCursor *)_cellSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellSelectionCursorImage
{
    return [NSImage imageWithSize:NSMakeSize(20, 20) flipped:YES drawingHandler:^(NSRect dstRect) {
        NSRect horizontalInner = NSMakeRect(7.0, 2.0, 2.0, 12.0);
        NSRect verticalInner = NSMakeRect(2.0, 7.0, 12.0, 2.0);
        
        NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
        NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
        
        // Set the shadow
        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowColor = NSColor.shadowColor;
        shadow.shadowBlurRadius = 2.0;
        shadow.shadowOffset = NSMakeSize(0, -1.0);
        
        [NSGraphicsContext.currentContext saveGraphicsState];
        
        [shadow set];
        
        [NSColor.blackColor set];
        NSRectFill(horizontalOuter);
        NSRectFill(verticalOuter);
        
        [NSGraphicsContext.currentContext restoreGraphicsState];
        
        // Fill them again to compensate for the shadows
        NSRectFill(horizontalOuter);
        NSRectFill(verticalOuter);
        
        [NSColor.whiteColor set];
        NSRectFill(horizontalInner);
        NSRectFill(verticalInner);
        
        return YES;
    }];
}

- (NSCursor *)_cellExtendSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorExtendSelectionImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellExtendSelectionCursorImage
{
    return [NSImage imageWithSize:NSMakeSize(20, 20) flipped:YES drawingHandler:^(NSRect dstRect) {
        NSRect horizontalInner = NSMakeRect(7.0, 1.0, 0.5, 12.0);
        NSRect verticalInner = NSMakeRect(1.0, 6.0, 12.0, 0.5);
        
        NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
        NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
        
        [NSGraphicsContext.currentContext saveGraphicsState];

        [NSColor.whiteColor set];
        NSRectFill(horizontalOuter);
        NSRectFill(verticalOuter);
        
        [NSGraphicsContext.currentContext restoreGraphicsState];
        
        // Fill them again to compensate for the shadows
        NSRectFill(horizontalOuter);
        NSRectFill(verticalOuter);
        
        [NSColor.blackColor set];
        NSRectFill(horizontalInner);
        NSRectFill(verticalInner);
        
        return YES;
    }];
}

- (NSImage *)_grabHandleImage;
{
    return [NSImage imageWithSize:NSMakeSize(kGRAB_HANDLE_SIDE_LENGTH, kGRAB_HANDLE_SIDE_LENGTH) flipped:YES
                   drawingHandler:^(NSRect dstRect) {
        NSGraphicsContext *gc = NSGraphicsContext.currentContext;
        
        // Save the current graphics context
        [gc saveGraphicsState];
        
        // Set the color in the current graphics context
        
        [NSColor.darkGrayColor setStroke];
        [NSColor.systemYellowColor setFill];
        
        // Create our circle path
        NSRect rect = NSMakeRect(1.0, 1.0, kGRAB_HANDLE_SIDE_LENGTH - 2.0, kGRAB_HANDLE_SIDE_LENGTH - 2.0);
        NSBezierPath *circlePath = [NSBezierPath bezierPath];
        circlePath.lineWidth = 0.5;
        [circlePath appendBezierPathWithOvalInRect: rect];
        
        // Outline and fill the path
        [circlePath fill];
        [circlePath stroke];
        
        // Restore the context
        [gc restoreGraphicsState];
        
        return YES;
    }];
}

@end

@implementation MBTableGridContentView (DragAndDrop)

- (void)_setDraggingColumnOrRow:(BOOL)flag
{
	isDraggingColumnOrRow = flag;
}

- (void)_setDropColumn:(NSInteger)columnIndex
{
    if (dropColumn != NSNotFound)
        [self setNeedsDisplayInRect:NSInsetRect([self rectOfColumn:dropColumn == _tableGrid.numberOfColumns ? dropColumn -1 : dropColumn],
                                                -(DROP_TARGET_LINE_WIDTH + DROP_TARGET_BOX_THICKNESS/2), 0)];
    
	dropColumn = columnIndex;
    
    if (dropColumn != NSNotFound)
        [self setNeedsDisplayInRect:NSInsetRect([self rectOfColumn:dropColumn == _tableGrid.numberOfColumns ? dropColumn -1 : dropColumn],
                                                -(DROP_TARGET_LINE_WIDTH + DROP_TARGET_BOX_THICKNESS/2), 0)];
}

- (void)_setDropRow:(NSInteger)rowIndex
{
    if (dropRow != NSNotFound)
        [self setNeedsDisplayInRect:NSInsetRect([self rectOfRow:dropRow == _tableGrid.numberOfRows ? dropRow -1 : dropRow], 0,
                                                -(DROP_TARGET_LINE_WIDTH + DROP_TARGET_BOX_THICKNESS/2))];
	dropRow = rowIndex;
    if (dropRow != NSNotFound)
        [self setNeedsDisplayInRect:NSInsetRect([self rectOfRow:dropRow == _tableGrid.numberOfRows ? dropRow -1 : dropRow], 0,
                                                -(DROP_TARGET_LINE_WIDTH + DROP_TARGET_BOX_THICKNESS/2))];
}

- (void)_timerAutoscrollCallback:(NSTimer *)aTimer
{
    if (autoscrollTimer) { // i.e. not cancelled
        [self stopAutoscrollTimer];
        NSEvent* event = NSApp.currentEvent;
        [self autoscroll:event];
        [self startAutoscrollTimer]; // non-repeating timer, restart it here
    }
}

@end
