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

#import "MBTableGridFooterView.h"
#import "MBTableGrid.h"
#import "MBTableGridContentView.h"
#import "MBFooterTextCell.h"

@interface MBTableGrid ()
- (MBTableGridContentView *)_contentView;
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (id)_footerValueForColumn:(NSUInteger)columnIndex;
- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex;
@end

@implementation MBTableGridFooterView

- (instancetype)initWithFrame:(NSRect)frameRect andTableGrid:(MBTableGrid *)tableGrid
{
    if(self = [super initWithFrame:frameRect]) {
		self.tableGrid = tableGrid;
        _defaultCell = [[MBFooterTextCell alloc] initTextCell:@""];
        [_defaultCell setBordered:NO];
		self.wantsLayer = YES;
		self.layer.drawsAsynchronously = YES;
		self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	
	// Draw the column footers
	NSUInteger numberOfColumns = self.tableGrid.numberOfColumns;
	NSUInteger column = 0;
    
	while (column < numberOfColumns) {
		NSRect cellFrame = [self footerRectOfColumn:column];
		
		// Only draw the header if we need to
		if ([self needsToDrawRect:cellFrame]) {
            NSCell *_cell = [self.tableGrid _footerCellForColumn:column];
            
            if (!_cell) {
                _cell = _defaultCell;
            }

            MBTableGridCell *cell = (MBTableGridCell *)_cell;
			[cell drawWithFrame:cellFrame inView:self];
		}
		
		column++;
	}
	
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint mouseLocationInContentView = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger mouseDownColumn = [self footerColumnAtPoint:mouseLocationInContentView];
    
    if (theEvent.clickCount == 1) {
        // Pass the event back to the MBTableGrid (Used to give First Responder status)
        [self.tableGrid mouseDown:theEvent];
        
        editedColumn = mouseDownColumn;
        
        NSCell *cell = [self.tableGrid _footerCellForColumn:mouseDownColumn];
		[self.tableGrid.delegate tableGrid:self.tableGrid footerCellClicked:cell forColumn:mouseDownColumn withEvent:theEvent];
    }
    
    [self setNeedsDisplay:YES];
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    NSRect modifiedRect = proposedVisibleRect;
    
    modifiedRect.origin.y = 0.0;
    
    return modifiedRect;
}

#pragma mark Layout Support

- (NSRect)footerRectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = [[self.tableGrid _contentView] rectOfColumn:columnIndex];
	rect.size.height = MBTableGridColumnHeaderHeight;
	
	return rect;
}

- (NSInteger)footerColumnAtPoint:(NSPoint)aPoint
{
    return [[self.tableGrid _contentView] columnAtPoint:aPoint];
}

@end
