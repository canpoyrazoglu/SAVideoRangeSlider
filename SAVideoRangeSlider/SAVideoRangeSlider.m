//
//  SAVideoRangeSlider.m
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Copyright (c) 2013 Andrei Solovjev - http://solovjev.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SAVideoRangeSlider.h"

@interface SAVideoRangeSlider ()

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIView *centerView;
@property (nonatomic, strong) NSURL *videoUrl;
@property (nonatomic, strong) SASliderLeft *leftThumb;
@property (nonatomic, strong) SASliderRight *rightThumb;
@property (nonatomic) CGFloat frame_width;
@property (nonatomic) Float64 durationSeconds;
@property(nonatomic,readonly) AVPlayer *assetPlayer;

@end

@implementation SAVideoRangeSlider{
    AVAsset *_asset;
    float duration;
}


#define SLIDER_BORDERS_SIZE 6.0f
#define BG_VIEW_BORDERS_SIZE 3.0f


- (id)initWithFrame:(CGRect)frame asset:(AVAsset*)asset{
    
    self = [super initWithFrame:frame];
    if (self) {
        _asset = asset;
        duration = CMTimeGetSeconds(asset.duration);
        _frame_width = frame.size.width;
        
        int thumbWidth = ceil(frame.size.width*0.08);
        
        _bgView = [[UIControl alloc] initWithFrame:CGRectMake(thumbWidth-BG_VIEW_BORDERS_SIZE, 0, frame.size.width-(thumbWidth*2)+BG_VIEW_BORDERS_SIZE*2, frame.size.height)];
        _bgView.layer.borderColor = [UIColor colorWithWhite:0.06 alpha:1].CGColor;
        _bgView.layer.borderWidth = BG_VIEW_BORDERS_SIZE;
        [self addSubview:_bgView];
        
        
        _topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, SLIDER_BORDERS_SIZE)];
        _topBorder.backgroundColor = [UIColor clearColor];
        [self addSubview:_topBorder];
        
        
        _bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height-SLIDER_BORDERS_SIZE, frame.size.width, SLIDER_BORDERS_SIZE)];
        _bottomBorder.backgroundColor = [UIColor clearColor];
        [self addSubview:_bottomBorder];
        
        
        _leftThumb = [[SASliderLeft alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        _leftThumb.contentMode = UIViewContentModeLeft;
        _leftThumb.userInteractionEnabled = YES;
        _leftThumb.clipsToBounds = YES;
        _leftThumb.backgroundColor = [UIColor clearColor];
        _leftThumb.layer.borderWidth = 0;
        [self addSubview:_leftThumb];
        
        
        UIPanGestureRecognizer *leftPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftPan:)];
        [_leftThumb addGestureRecognizer:leftPan];
        
        
        _rightThumb = [[SASliderRight alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        
        _rightThumb.contentMode = UIViewContentModeRight;
        _rightThumb.userInteractionEnabled = YES;
        _rightThumb.clipsToBounds = YES;
        _rightThumb.backgroundColor = [UIColor clearColor];
        [self addSubview:_rightThumb];
        
        UIPanGestureRecognizer *rightPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightPan:)];
        [_rightThumb addGestureRecognizer:rightPan];
        
        _rightPosition = frame.size.width;
        _leftPosition = 0;
        
        
        
        
        _centerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _centerView.backgroundColor = [UIColor clearColor];
        [self addSubview:_centerView];
        
        UIPanGestureRecognizer *centerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCenterPan:)];
        [_centerView addGestureRecognizer:centerPan];
        
        [self setNeedsLayout];
        
        [self getMovieFrame];
    }
    
    return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


-(void)setMaxGap:(NSInteger)maxGap{
    _leftPosition = 0;
    _rightPosition = _frame_width*maxGap/_durationSeconds;
    _maxGap = maxGap;
}

-(void)setMinGap:(NSInteger)minGap{
    _leftPosition = 0;
    _rightPosition = _frame_width*minGap/_durationSeconds;
    _minGap = minGap;
}


- (void)delegateNotification
{
    if ([_delegate respondsToSelector:@selector(videoRange:didChangeLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didChangeLeftPosition:self.leftPosition rightPosition:self.rightPosition];
    }
    
}


-(void)generateImpactFeedback{
    if (@available(iOS 10,*)) {
        static UIImpactFeedbackGenerator *feedbackGenerator;
        if(!feedbackGenerator){
            feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [feedbackGenerator prepare];
        }
        [feedbackGenerator impactOccurred];
    }
}

#pragma mark - Gestures

- (void)handleLeftPan:(UIPanGestureRecognizer *)gesture
{
         [self.delegate.assetPlayer pause];
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        BOOL leftPositionWasZero = _leftPosition == 0;
        
        
        
        _leftPosition += translation.x;
        if (_leftPosition < 0) {
            _leftPosition = 0;
        }
        
        //snap if very close to zero
        if(_leftPosition < 3){
            _leftPosition = 0;
        }
        if(_leftPosition == 0 && !leftPositionWasZero){
            [self generateImpactFeedback];
        }
        
        if (
            (_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))
            ){
            _leftPosition -= translation.x;
            static BOOL suppressFeedback;
            if(!suppressFeedback){
                suppressFeedback = YES;
                [self generateImpactFeedback];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    suppressFeedback = NO;
                });
            }
        }
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self setNeedsLayout];
        
        [self delegateNotification];
        if([self.delegate respondsToSelector:@selector(videoRangeDidInteractWithTime:)]){
            [self.delegate videoRangeDidInteractWithTime:[self timeFromPosition:self.rightPosition]];
        }
        [self.assetPlayer seekToTime:[self timeFromPosition:self.leftPosition] toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }else if(gesture.state == UIGestureRecognizerStateEnded){
        if([self.delegate respondsToSelector:@selector(videoRangeDidFinishInteractingWithBeginning:ending:)]){
            [self.delegate videoRangeDidFinishInteractingWithBeginning:[self timeFromPosition:self.leftPosition] ending:[self timeFromPosition:self.rightPosition]];
        }
        [self.assetPlayer seekToTime:[self timeFromPosition:self.leftPosition]];
        [self.delegate.assetPlayer play];
    }
    
    
}

-(AVPlayer*)assetPlayer{
    return self.delegate.assetPlayer;
}


- (void)handleRightPan:(UIPanGestureRecognizer *)gesture
{
     [self.delegate.assetPlayer pause];
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        BOOL rightPositionWasFrameWidth = _rightPosition == _frame_width;
        
        CGPoint translation = [gesture translationInView:self];
        _rightPosition += translation.x;
        if (_rightPosition < 0) {
            _rightPosition = 0;
        }
        
        if (_rightPosition > _frame_width){
            _rightPosition = _frame_width;
        }
        
        
        
        
        if (_rightPosition-_leftPosition <= 0){
            _rightPosition -= translation.x;
        }
        
        //snap if very close to zero
        if(_rightPosition > _frame_width - 3){
            _rightPosition = _frame_width;
        }
        if(_rightPosition == _frame_width && !rightPositionWasFrameWidth){
            [self generateImpactFeedback];
        }
        
        if ((_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))){
            _rightPosition -= translation.x;
            static BOOL suppressFeedback;
            if(!suppressFeedback){
                suppressFeedback = YES;
                [self generateImpactFeedback];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    suppressFeedback = NO;
                });
            }
        }
        
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self setNeedsLayout];
        
        [self delegateNotification];
        if([self.delegate respondsToSelector:@selector(videoRangeDidInteractWithTime:)]){
            [self.delegate videoRangeDidInteractWithTime:[self timeFromPosition:self.rightPosition]];
        }
        [self.assetPlayer seekToTime:[self timeFromPosition:self.rightPosition] toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }else if(gesture.state == UIGestureRecognizerStateEnded){
        if([self.delegate respondsToSelector:@selector(videoRangeDidFinishInteractingWithBeginning:ending:)]){
            [self.delegate videoRangeDidFinishInteractingWithBeginning:[self timeFromPosition:self.leftPosition] ending:[self timeFromPosition:self.rightPosition]];
        }
        [self.assetPlayer seekToTime:[self timeFromPosition:self.leftPosition] toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        [self.delegate.assetPlayer play];
    }
    
    
}

-(CMTime)timeFromPosition:(float)position{
    CMTime targetTime = CMTimeMakeWithSeconds(position, _asset.duration.timescale);
    return targetTime;
}


- (void)handleCenterPan:(UIPanGestureRecognizer *)gesture
{
    
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _leftPosition += translation.x;
        _rightPosition += translation.x;
        
        if (_rightPosition > _frame_width || _leftPosition < 0){
            _leftPosition -= translation.x;
            _rightPosition -= translation.x;
        }
        
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self setNeedsLayout];
        
        [self delegateNotification];
        
    }
    
    
}


- (void)layoutSubviews
{
    CGFloat inset = _leftThumb.frame.size.width / 2;
    
    _leftThumb.center = CGPointMake(_leftPosition+inset, _leftThumb.frame.size.height/2);
    
    _rightThumb.center = CGPointMake(_rightPosition-inset, _rightThumb.frame.size.height/2);
    
    _topBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, 0, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    _bottomBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _bgView.frame.size.height-SLIDER_BORDERS_SIZE, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    
    _centerView.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _centerView.frame.origin.y, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width, _centerView.frame.size.height);
    
    
}




#pragma mark - Video

-(void)getMovieFrame{
    
    AVAsset *myAsset = _asset;
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:myAsset];
    float scaleFactor = [UIScreen mainScreen].scale;
    self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width*scaleFactor, _bgView.frame.size.height*scaleFactor);
    
    int picWidth = 60;
    
    // First image
    NSError *error;
    CMTime actualTime;
    CGImageRef halfWayImage = [self.imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:&actualTime error:&error];
    if (halfWayImage != NULL) {
        UIImage *videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationRight];
        
        UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];
        tmp.contentMode = UIViewContentModeScaleAspectFill;
        CGRect rect=tmp.frame;
        rect.size.width=picWidth;
        rect.size.height = self.frame.size.height;
        tmp.frame=rect;
        
        UIView *container = [[UIView alloc] initWithFrame:tmp.frame];
        tmp.frame =  CGRectMake(0, 0, tmp.frame.size.width, tmp.frame.size.height);
        container.clipsToBounds = YES;
        //
        [container addSubview:tmp];
        [_bgView addSubview:container];
        
        
        //[_bgView addSubview:tmp];
        picWidth = tmp.frame.size.width;
        CGImageRelease(halfWayImage);
    }
    
    
    _durationSeconds = CMTimeGetSeconds([myAsset duration]);
    
    int picsCnt = ceil(_bgView.frame.size.width / picWidth);
    
    NSMutableArray *allTimes = [[NSMutableArray alloc] init];
    
    int time4Pic = 0;
    
    int prefreWidth=0;
    for (int i=1, ii=1; i<picsCnt; i++){
        time4Pic = i*picWidth;
        
        CMTime timeFrame = CMTimeMakeWithSeconds(_durationSeconds*time4Pic/_bgView.frame.size.width, 600);
        
        [allTimes addObject:[NSValue valueWithCMTime:timeFrame]];
        
        
        CGImageRef halfWayImage = [self.imageGenerator copyCGImageAtTime:timeFrame actualTime:&actualTime error:&error];
        
        
        UIImage *videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationRight];
        
        UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];
        tmp.contentMode = UIViewContentModeScaleAspectFill;
        
        
        
        CGRect currentFrame = tmp.frame;
        currentFrame.origin.x = ii*picWidth;
        
        currentFrame.size.width=picWidth;
        prefreWidth+=currentFrame.size.width;
        
        if( i == picsCnt-1){
            currentFrame.size.width-=6;
        }
        currentFrame.size.height = self.frame.size.height;
        tmp.frame = currentFrame;
        int all = (ii+1)*tmp.frame.size.width;
        
        if (all > _bgView.frame.size.width){
            int delta = all - _bgView.frame.size.width;
            currentFrame.size.width -= delta;
        }
        
        ii++;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIView *container = [[UIView alloc] initWithFrame:tmp.frame];
            tmp.frame =  CGRectMake(0, 0, tmp.frame.size.width, tmp.frame.size.height);
            container.clipsToBounds = YES;
            //
            [container addSubview:tmp];
            [_bgView addSubview:container];
            //  tmp.center = container.center;
        });
        
        
        
        
        CGImageRelease(halfWayImage);
        
    }
    
    
    return;
}




#pragma mark - Properties

- (CGFloat)leftPosition
{
    return _leftPosition * _durationSeconds / _frame_width;
}


- (CGFloat)rightPosition
{
    return _rightPosition * _durationSeconds / _frame_width;
}


@end
