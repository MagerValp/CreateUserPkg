//
//  CUPImageSelector.m
//  CreateUserPkg
//
//  Created by Per Olofsson on 2012-06-29.
//  Copyright (c) 2012 University of Gothenburg. All rights reserved.
//

#import "CUPImageSelector.h"

@implementation CUPImageSelector

@synthesize imageData = _imageData;
@synthesize imagePath = _imagePath;


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeTIFF, NSURLPboardType, nil]];
        self.imageData = nil;
        self.imagePath = nil;
    }
    
    return self;
}

- (void)dealloc
{
    self.imageData = nil;
    self.imagePath = nil;
    [super dealloc];
}

- (void)saveJpegData:(NSData *)data
{
    NSBitmapImageRep *imgrep = [NSBitmapImageRep imageRepWithData:data];
    self.imageData = [imgrep representationUsingType:NSJPEGFileType properties:nil];
}

- (void)saveUserPicturesPath:(NSURL *)url
{
    if (url != nil) {
        if ([url isFileURL] == YES) {
            NSString *path = [url path];
            if ([path hasPrefix:@"/Library/User Pictures/"]) {
                self.imagePath = path;
            }
        }
    }
}

- (void)displayImageData
{
    NSImage *image = [[NSImage alloc] initWithData:self.imageData];
    [self setImage:image];
    [image release];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric) {
        return NSDragOperationGeneric;
    } else {
        return NSDragOperationNone;
    }
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSString *droppedType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSPasteboardTypeTIFF, NSURLPboardType, nil]];
    NSData *droppedData = [pboard dataForType:droppedType];
    NSURL *droppedURL = [NSURL URLFromPasteboard:pboard];
    
    if (droppedData == nil) {
        return NO;
    }
    
    //FIXME: handle droppedType and read data from opened URL instead
    [self saveUserPicturesPath:droppedURL];
    [self saveJpegData:droppedData];
    [self displayImageData];
    
    [self setNeedsDisplay:YES];
    return YES;
}

@end
