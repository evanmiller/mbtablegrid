//
//  MBFooterTextCell.m
//  MBTableGrid
//
//  Created by David Sinclair on 2015-02-27.
//

#import "MBFooterTextCell.h"

@interface MBFooterTextCell ()

@property (nonatomic, strong) NSFont *attributedTitleFont;

@end

#pragma mark -

@implementation MBFooterTextCell

- (NSAttributedString *)attributedTitle
{
    NSColor *color = [NSColor controlTextColor];
    NSDictionary *attributes = @{NSFontAttributeName : self.attributedTitleFont, NSForegroundColorAttributeName : color};
    
    return [[NSAttributedString alloc] initWithString:self.title attributes:attributes];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    static CGFloat TEXT_PADDING = 6;
    NSRect textFrame;
    CGSize stringSize = self.attributedTitle.size;
    textFrame = NSMakeRect(cellFrame.origin.x + TEXT_PADDING,
						   cellFrame.origin.y + (cellFrame.size.height - stringSize.height)/2,
						   cellFrame.size.width - TEXT_PADDING,
						   stringSize.height);

    [self.attributedTitle drawWithRect:textFrame options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
}

- (NSFont*)attributedTitleFont
{
	if (_attributedTitleFont == nil) {
		_attributedTitleFont = [NSFont labelFontOfSize:NSFont.labelFontSize];
	}
	return _attributedTitleFont;
}

@end
