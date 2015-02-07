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

@interface MBTableGrid (Private)
- (NSString *)_headerStringForColumn:(NSUInteger)columnIndex;
- (MBTableGridContentView *)_contentView;
@end

@implementation MBTableGridFooterView

- (id)initWithFrame:(NSRect)frameRect
{
	if(self = [super initWithFrame:frameRect]) {
		// Setup the header cell
		_footerCell = [[MBTableGridFooterCell alloc] init];
	}
	return self;
}

- (void)drawRect:(NSRect)rect {
	
	// Draw the column headers
	NSUInteger numberOfColumns = [self tableGrid].numberOfColumns;
	NSUInteger column = 0;
	while (column < numberOfColumns) {
		NSRect headerRect = [self headerRectOfColumn:column];
		
		// Only draw the header if we need to
		if ([self needsToDrawRect:headerRect]) {
//			// Check if any part of the selection is in this column
//			NSIndexSet *selectedColumns = [[self tableGrid] selectedColumnIndexes];
//			if ([selectedColumns containsIndex:column]) {
//				[headerCell setState:NSOnState];
//			} else {
//				[headerCell setState:NSOffState];
//			}
			
			[_footerCell setStringValue:[[self tableGrid] _headerStringForColumn:column]];
			[_footerCell drawWithFrame:headerRect inView:self];
			
		}
		
		column++;
	}
	
}

- (BOOL)isFlipped
{
	return YES;
}

#pragma mark -
#pragma mark Subclass Methods

- (MBTableGrid *)tableGrid
{
	return (MBTableGrid *)[[self enclosingScrollView] superview];
}

#pragma mark Layout Support

- (NSRect)headerRectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = [[[self tableGrid] _contentView] rectOfColumn:columnIndex];
	rect.size.height = MBTableGridColumnHeaderHeight;
	
	return rect;
}

@end
