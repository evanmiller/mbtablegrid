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

#import "MBTableGridCell.h"

@interface MBTableGridCell ()

@property (nonatomic, strong) NSColor *borderColor;

@end

#pragma mark -

@implementation MBTableGridCell

-(instancetype)initTextCell:(NSString *)aString
{
    if (self = [super initTextCell:aString])
    {
        self.backgroundColor = NSColor.clearColor;
        self.borderColor = NSColor.quaternaryLabelColor;
		self.truncatesLastVisibleLine = YES;
        return self;
    }
    
    return nil;
}

- (void)drawBorderWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [_borderColor set];
    
    // Draw the right border
    NSRect rightLine = NSMakeRect(NSMaxX(cellFrame)-1.0, NSMinY(cellFrame), 1.0, NSHeight(cellFrame));
    NSRectFill(rightLine);
    
    // Draw the bottom border
    NSRect bottomLine = NSMakeRect(NSMinX(cellFrame), NSMaxY(cellFrame)-1.0, NSWidth(cellFrame), 1.0);
    NSRectFill(bottomLine);
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [self drawBorderWithFrame:cellFrame inView:controlView];
	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// Do not draw any highlight.
	return nil;
}

@end
