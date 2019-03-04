#import "bdasr.h"
#import "BDSEventManager.h"
#import "BDSASRDefines.h"
#import "BDSASRParameters.h"
#import <AVFoundation/AVFoundation.h>
#import "BDRecognizerViewController.h"
#import "BDRecognizerViewDelegate.h"
#import "BDRecognizerViewParamsObject.h"

@interface bdasr ()<BDSClientASRDelegate,BDRecognizerViewDelegate, UIAlertViewDelegate> {
    // Member variables go here.
    NSString* API_KEY;
    NSString* SECRET_KEY;
    NSString* APP_ID;
    
    NSString *callbackId;
}

@property (strong, nonatomic) BDSEventManager *asrEventManager;
@property (strong, nonatomic) NSBundle *bdsClientBundle;
@property(nonatomic, strong) NSFileHandle *fileHandler;
@property(nonatomic, strong) BDRecognizerViewController *recognizerViewController;

- (void)startSpeechRecognize:(CDVInvokedUrlCommand *)command;
- (void)closeSpeechRecognize:(CDVInvokedUrlCommand *)command;
- (void)cancelSpeechRecognize:(CDVInvokedUrlCommand *)command;
- (void)startSpeechUI:(CDVInvokedUrlCommand *)command;
@end

@implementation bdasr

- (void)pluginInitialize {
    [self.commandDelegate runInBackground:^{
        CDVViewController *viewController = (CDVViewController *)self.viewController;
        APP_ID = [viewController.settings objectForKey:@"bdasrappid"];
        API_KEY = [viewController.settings objectForKey:@"bdasrapikey"];
        SECRET_KEY = [viewController.settings objectForKey:@"bdasrsecretkey"];
        [self initAsrEventManager];
    }];
    
}


#pragma mark - bdasr function

- (void)startSpeechRecognize:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        if ([self checkMicPermission] == 0) {
            [self getVoicePermission];
        } else {
            callbackId = command.callbackId;
            // 发送指令：启动识别
            [self.asrEventManager setDelegate:self];
            [self.asrEventManager setParameter:nil forKey:BDS_ASR_AUDIO_FILE_PATH];
            [self.asrEventManager setParameter:nil forKey:BDS_ASR_AUDIO_INPUT_STREAM];
            [self.asrEventManager sendCommand:BDS_ASR_CMD_START];
        }
    }];
    
}
- (void)startSpeechUI:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        if ([self checkMicPermission] == 0) {
            [self getVoicePermission];
        } else {
            callbackId = command.callbackId;
            NSObject *obj=[command.arguments objectAtIndex:0];
            // 发送指令：启动识别
            [self.asrEventManager setParameter:@"" forKey:BDS_ASR_AUDIO_FILE_PATH];
            [self configFileHandler];
            [self configRecognizerViewController:obj];
            [self.recognizerViewController startVoiceRecognition];
        }
    }];
   
}
- (void)closeSpeechRecognize:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [self.asrEventManager sendCommand:BDS_ASR_CMD_STOP];
    }];
    
}

- (void)cancelSpeechRecognize:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [self.asrEventManager sendCommand:BDS_ASR_CMD_CANCEL];
    }];
}
#pragma mark - permission
- (void)getVoicePermission{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"您还未授权[TSM]使用麦克风" delegate:self
                                          cancelButtonTitle:@"知道了" otherButtonTitles:@"去设置", nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert show];
    });
}
- (NSInteger)checkMicPermission {
    NSInteger flag = 0;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (authStatus) {
        case AVAuthorizationStatusNotDetermined:
            //没有询问是否开启麦克风
            flag = 1;
            break;
        case AVAuthorizationStatusRestricted:
            //未授权，家长限制
            flag = 0;
            break;
        case AVAuthorizationStatusDenied:
            //玩家未授权
            flag = 0;
            break;
        case AVAuthorizationStatusAuthorized:
            //玩家授权
            flag = 2;
            break;
        default:
            break;
    }
    return flag;
}

#pragma mark - bdasr config
- (void)initAsrEventManager {
    // 创建语音识别对象
    self.asrEventManager = [BDSEventManager createEventManagerWithName:BDS_ASR_NAME];
    // 设置语音识别代理
    [self.asrEventManager setDelegate:self];
    // 参数配置：在线身份验证
    [self.asrEventManager setParameter:@[API_KEY, SECRET_KEY] forKey:BDS_ASR_API_SECRET_KEYS];
    //设置 APPID
    [self.asrEventManager setParameter:APP_ID forKey:BDS_ASR_OFFLINE_APP_CODE];
    
    //配置端点检测（二选一）
    [self configModelVAD];
    
    //    [self configDNNMFE];
    //     [self.asrEventManager setParameter:@"15361" forKey:BDS_ASR_PRODUCT_ID];
    // ---- 语义与标点 -----
    //    [self enableNLU];
    //    [self enablePunctuation];
    // ------------------------
}

- (void)configRecognizerViewController:(NSObject *) obj {
    BDRecognizerViewParamsObject *paramsObject = [[BDRecognizerViewParamsObject alloc] init];
    paramsObject.isShowTipAfterSilence = YES;
    paramsObject.isShowHelpButtonWhenSilence = NO;
    NSString *tipsTitle;
    NSArray *tipsList;
    tipsTitle=[obj valueForKey:@"tipsTitle"];
    if ([tipsTitle isKindOfClass:[NSNull class]]) tipsTitle=@"您可以这样说：";
    tipsList=[obj valueForKey:@"tipsList"];
    if ([tipsList isKindOfClass:[NSNull class]]) tipsList=[NSArray arrayWithObjects:@"我要吃饭", @"我要买电影票", @"我要订酒店", nil];
   
    paramsObject.tipsTitle = tipsTitle;
    paramsObject.tipsList = tipsList;
    paramsObject.waitTime2ShowTip = 0.5;
    paramsObject.isHidePleaseSpeakSection = YES;
    paramsObject.disableCarousel = YES;
    self.recognizerViewController = [[BDRecognizerViewController alloc] initRecognizerViewControllerWithOrigin:CGPointMake(9, 80)
                                                                                                         theme:nil
                                                                                              enableFullScreen:YES
                                                                                                  paramsObject:paramsObject
                                                                                                      delegate:self];
}

- (void)configFileHandler {
    self.fileHandler = [self createFileHandleWithName:@"recoder.pcm" isAppend:NO];
}
//- (void) enableNLU {
//    // ---- 开启语义理解 -----
//    [self.asrEventManager setParameter:@(YES) forKey:BDS_ASR_ENABLE_NLU];
//    [self.asrEventManager setParameter:@"15361" forKey:BDS_ASR_PRODUCT_ID];
//}
////
//- (void) enablePunctuation {
//    // ---- 开启标点输出 -----
//    [self.asrEventManager setParameter:@(NO) forKey:BDS_ASR_DISABLE_PUNCTUATION];
//    // 普通话标点
//    //    [self.asrEventManager setParameter:@"1537" forKey:BDS_ASR_PRODUCT_ID];
//    // 英文标点
//    [self.asrEventManager setParameter:@"1737" forKey:BDS_ASR_PRODUCT_ID];
//}


- (void)configModelVAD {
    NSString *modelVAD_filepath = [[NSBundle mainBundle] pathForResource:@"bds_easr_basic_model" ofType:@"dat"];
    [self.asrEventManager setParameter:modelVAD_filepath forKey:BDS_ASR_MODEL_VAD_DAT_FILE];
    [self.asrEventManager setParameter:@(YES) forKey:BDS_ASR_ENABLE_MODEL_VAD];
}

#pragma mark - Private: File

- (NSString *)getFilePath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths && [paths count]) {
        return [[paths objectAtIndex:0] stringByAppendingPathComponent:fileName];
    } else {
        return nil;
    }
}
- (NSFileHandle *)createFileHandleWithName:(NSString *)aFileName isAppend:(BOOL)isAppend {
    NSFileHandle *fileHandle = nil;
    NSString *fileName = [self getFilePath:aFileName];
    
    int fd = -1;
    if (fileName) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]&& !isAppend) {
            [[NSFileManager defaultManager] removeItemAtPath:fileName error:nil];
        }
        
        int flags = O_WRONLY | O_APPEND | O_CREAT;
        fd = open([fileName fileSystemRepresentation], flags, 0644);
    }
    
    if (fd != -1) {
        fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    }
    
    return fileHandle;
}

#pragma mark - BDRecognizerViewDelegate

- (void)onRecordDataArrived:(NSData *)recordData sampleRate:(int)sampleRate
{
    //    [self.fileHandler writeData:(NSData *)recordData];
}

- (void)onEndWithViews:(BDRecognizerViewController *)aBDRecognizerViewController withResult:(id)aResult
{
    if (aResult) {
        [self getDescriptionForDic:aResult];
        if (aResult && [aResult isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = @{
                                   @"type": @"asrFinish",
                                   @"message" :aResult
                                   };
            [self sendEvent:dict];
        }
    }
    [self.asrEventManager setDelegate:self];
}
#pragma mark - MVoiceRecognitionClientDelegate

- (void)VoiceRecognitionClientWorkStatus:(int)workStatus obj:(id)aObj {
    switch (workStatus) {
        case EVoiceRecognitionClientWorkStatusNewRecordData: {
            //            [self.fileHandler writeData:(NSData *)aObj];
            break;
        }
        
        case EVoiceRecognitionClientWorkStatusStartWorkIng: {
            NSDictionary *logDic = [self parseLogToDic:aObj];
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: start vr, log: %@\n", logDic]];
            NSDictionary *dict = @{
                                   @"type": @"asrReady",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            break;
        }
        case EVoiceRecognitionClientWorkStatusStart: {
            NSDictionary *dict = @{
                                   @"type": @"asrBegin",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            break;
        }
        case EVoiceRecognitionClientWorkStatusEnd: {
            
            NSDictionary *dict = @{
                                   @"type": @"asrEnd",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            
            break;
        }
        case EVoiceRecognitionClientWorkStatusFlushData: {
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: partial result - %@.\n\n", [self getDescriptionForDic:aObj]]];
            if (aObj && [aObj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = @{
                                       @"type": @"asrText",
                                       @"message" :aObj
                                       };
                
                [self sendEvent:dict];
            }
            break;
        }
        case EVoiceRecognitionClientWorkStatusFinish: {
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: asr finish - %@.\n\n", [self getDescriptionForDic:aObj]]];
            
            if (aObj && [aObj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = @{
                                       @"type": @"asrFinish",
                                       @"message" :aObj
                                       };
                
                [self sendEvent:dict];
            }
            break;
        }
        case EVoiceRecognitionClientWorkStatusMeterLevel: {
            break;
        }
        case EVoiceRecognitionClientWorkStatusCancel: {
            NSDictionary *dict = @{
                                   @"type": @"asrCancel",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            break;
        }
        case EVoiceRecognitionClientWorkStatusError: {
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: encount error - %@.\n", (NSError *)aObj]];
            [self sendError:[NSString stringWithFormat:@"CALLBACK: encount error - %@.\n", (NSError *)aObj]];
            break;
        }
        case EVoiceRecognitionClientWorkStatusLoaded: {
            [self printLogTextView:@"CALLBACK: offline engine loaded.\n"];
            break;
        }
        case EVoiceRecognitionClientWorkStatusUnLoaded: {
            [self printLogTextView:@"CALLBACK: offline engine unLoaded.\n"];
            break;
        }
        case EVoiceRecognitionClientWorkStatusChunkThirdData: {
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: Chunk 3-party data length: %lu\n", (unsigned long)[(NSData *)aObj length]]];
            break;
        }
        case EVoiceRecognitionClientWorkStatusChunkNlu: {
            NSString *nlu = [[NSString alloc] initWithData:(NSData *)aObj encoding:NSUTF8StringEncoding];
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: Chunk NLU data: %@\n", nlu]];
            NSLog(@"%@", nlu);
            break;
        }
        case EVoiceRecognitionClientWorkStatusChunkEnd: {
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: Chunk end, sn: %@.\n", aObj]];
            
            break;
        }
        case EVoiceRecognitionClientWorkStatusFeedback: {
            NSDictionary *logDic = [self parseLogToDic:aObj];
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK Feedback: %@\n", logDic]];
            break;
        }
        case EVoiceRecognitionClientWorkStatusRecorderEnd: {
            [self printLogTextView:@"CALLBACK: recorder closed.\n"];
            break;
        }
        case EVoiceRecognitionClientWorkStatusLongSpeechEnd: {
            [self printLogTextView:@"CALLBACK: Long Speech end.\n"];
            break;
        }
        default:
        break;
    }
}
#pragma mark - data handle
- (void)sendEvent:(NSDictionary *)dict {
    if (!callbackId) return;
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    
}

- (void)sendError:(NSString *)errMsg {
    if (!callbackId) return;
    
    NSDictionary *dict = @{
                           @"type": @"asrError",
                           @"message": errMsg
                           };
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dict];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}



- (void)printLogTextView:(NSString *)logString
{
    NSLog(@"%@", logString);
}

- (NSDictionary *)parseLogToDic:(NSString *)logString
{
    NSArray *tmp = NULL;
    NSMutableDictionary *logDic = [[NSMutableDictionary alloc] initWithCapacity:3];
    NSArray *items = [logString componentsSeparatedByString:@"&"];
    for (NSString *item in items) {
        tmp = [item componentsSeparatedByString:@"="];
        if (tmp.count == 2) {
            [logDic setObject:tmp.lastObject forKey:tmp.firstObject];
        }
    }
    return logDic;
}

- (NSString *)getDescriptionForDic:(NSDictionary *)dic {
    if (dic) {
        return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dic
                                                                              options:NSJSONWritingPrettyPrinted
                                                                                error:nil] encoding:NSUTF8StringEncoding];
    }
    return nil;
}


#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}


@end

