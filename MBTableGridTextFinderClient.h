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
}

- (id)initWithTableGrid:(MBTableGrid *)tableGrid;

@end
