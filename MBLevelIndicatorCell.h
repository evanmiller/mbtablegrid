//
//  MBLevelIndicatorCell.h
//  MBTableGrid
//
//  Created by Brendan Duddridge on 2014-11-17.
//
//

#import <Cocoa/Cocoa.h>
#import "MBTableGridEditable.h"

@interface MBLevelIndicatorCell : NSLevelIndicatorCell<MBTableGridEditable>

@property (nonatomic, strong) NSImage *accessoryButtonImage;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView withBackgroundColor:(NSColor *)backgroundColor;

@end
