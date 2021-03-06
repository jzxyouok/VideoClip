//
//  AVAsset+FMLVideo.m
//  VideoClip
//
//  Created by samo on 16/7/27.
//  Copyright © 2016年 Collion. All rights reserved.
//

#import "AVAsset+FMLVideo.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void *cImgGenerator = &cImgGenerator;
static void *cFrameRate = &cFrameRate;

@implementation AVAsset (FMLVideo)

- (void)fml_getImagesCount:(NSUInteger)imageCount imageBackBlock:(void (^)(UIImage *))imageBackBlock
{
    Float64 durationSeconds = [self fml_getSeconds];
    
    // 获取视频的帧数
    float fps = [self fml_getFPS];
    
    NSMutableArray *times = [NSMutableArray array];
    Float64 totalFrames = durationSeconds * fps; //获得视频总帧数
    
    Float64 perFrames = totalFrames / imageCount; // 一共切8张图
    Float64 frame = 0;
    
    CMTime timeFrame;
    while (frame < totalFrames) {
        timeFrame = CMTimeMake(frame, fps); //第i帧  帧率
        NSValue *timeValue = [NSValue valueWithCMTime:timeFrame];
        [times addObject:timeValue];
        
        frame += perFrames;
    }
    
    AVAssetImageGenerator *imgGenerator = [[AVAssetImageGenerator alloc] initWithAsset:self];
    // 防止时间出现偏差
    imgGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imgGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imgGenerator.appliesPreferredTrackTransform = YES;  // 截图的时候调整到正确的方向
    
    [imgGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        switch (result) {
            case AVAssetImageGeneratorCancelled:
                break;
            case AVAssetImageGeneratorFailed:
                break;
            case AVAssetImageGeneratorSucceeded: {
                UIImage *displayImage = [UIImage imageWithCGImage:image];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    !imageBackBlock ? : imageBackBlock(displayImage);
                });
            }
                break;
        }
    }];
}

- (Float64)fml_getSeconds
{
    CMTime cmtime = self.duration; //视频时间信息结构体
    return CMTimeGetSeconds(cmtime); //视频总秒数
}

- (float)fml_getFPS
{
    if (!self.frameRate) {
        float fps = [[self tracksWithMediaType:AVMediaTypeVideo].lastObject nominalFrameRate];
        self.frameRate = @(fps);
    }
    
    return self.frameRate.floatValue;
}

- (void)fml_getThumbailImageRequestAtTimeSecond:(Float64)timeBySecond imageBackBlock:(void (^)(UIImage *))imageBackBlock
{
    if (!self.imgGenerator) {
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self];
        imageGenerator.appliesPreferredTrackTransform = YES;
        imageGenerator.apertureMode =AVAssetImageGeneratorApertureModeEncodedPixels;

        self.imgGenerator = imageGenerator;
    }
    
    NSArray *array = [NSArray arrayWithObject:[NSValue valueWithCMTime:CMTimeMake(timeBySecond * self.fml_getFPS, self.fml_getFPS)]];
    [self.imgGenerator generateCGImagesAsynchronouslyForTimes:array completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        switch (result) {
            case AVAssetImageGeneratorCancelled:
                break;
            case AVAssetImageGeneratorFailed:
                break;
            case AVAssetImageGeneratorSucceeded: {
                UIImage *displayImage = [UIImage imageWithCGImage:image];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    !imageBackBlock ? : imageBackBlock(displayImage);
                });
            }
                break;
        }
    }];
}

#pragma mark - getter和setter
- (AVAssetImageGenerator *)imgGenerator
{
    return objc_getAssociatedObject(self, &cImgGenerator);
}

- (void)setImgGenerator:(AVAssetImageGenerator *)imgGenerator
{
    objc_setAssociatedObject(self, &cImgGenerator, imgGenerator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)frameRate
{
    return objc_getAssociatedObject(self, &cFrameRate);
}

- (void)setFrameRate:(NSNumber *)frameRate
{
    objc_setAssociatedObject(self, &cFrameRate, frameRate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end



/**
 CMTimeMake(time, timeScale)
 
 time指的就是時間(不是秒),
 而時間要換算成秒就要看第二個參數timeScale了.
 timeScale指的是1秒需要由幾個frame構成(可以視為fps),
 因此真正要表達的時間就會是 time / timeScale 才會是秒
 
 */
