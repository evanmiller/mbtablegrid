//
//  MBTableGridEditable.h
//  MBTableGrid
//
//  Created by Brandon Evans on 2014-11-04.
//
//

#import <Foundation/Foundation.h>

@protocol MBTableGridEditable <NSObject>

@optional
/**
 *  If a cell should be edited when the user first clicks in the cell (like a checkbox instead of a text field), return YES. If you return YES then it's recommended that your cell override `- hitTestForEvent:inRect:ofView:` to verify whether or not the location of the mouse is correct to edit the cell. For example, a checkbox cell would return YES from `- hitTestForEvent:inRect:ofView:` if the mouse was in the frame of the checkbox itself and NO if it was elsewhere in the cell or outside the cell.
 */
@property (nonatomic, assign, readonly) BOOL editOnFirstClick;

@end
