//
//  MBImageCell.h
//  MBTableGrid
//
//  Created by Brendan Duddridge on 2014-11-13.
//
//

#import <Cocoa/Cocoa.h>

@interface MBImageCell : NSImageCell

@property (nonatomic, strong) NSImage *accessoryButtonImage;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView withBackgroundColor:(NSColor *)backgroundColor;

@end
