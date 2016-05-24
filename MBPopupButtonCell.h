//
//  MBPopupButtonCell.h
//  MBTableGrid
//
//  Created by Brendan Duddridge on 2014-10-27.
//
//

#import <Cocoa/Cocoa.h>

@interface MBPopupButtonCell : NSPopUpButtonCell

@property (nonatomic, strong) NSImage *accessoryButtonImage;
@property (nonatomic, strong) NSColor *borderColor;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView withBackgroundColor:(NSColor *)backgroundColor;

@end
