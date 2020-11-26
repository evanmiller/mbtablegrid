//
//  MBTableGridTextFinderClient.h
//  MBTableGrid
//
//  Created by Evan Miller on 1/17/20.
//

#import <Cocoa/Cocoa.h>

@class MBTableGrid;

@interface MBTableGridTextFinderClient : NSObject<NSTextFinderClient> {
    MBTableGrid *_tableGrid;
    
    NSMutableDictionary<NSNumber *, NSDictionary<NSString *, id> *> *_pending_replacements;
}

- (instancetype)initWithTableGrid:(MBTableGrid *)tableGrid;

@end
