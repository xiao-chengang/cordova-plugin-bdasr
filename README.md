### 前言
1. 这是一个百度语音识别的cordova插件。为什么使用百度语音识别，因为是免费的，识别的准确度也还挺不错的。
2. 这个插件只包含语音识别功能，不包含其他的比如唤醒、长语音功能。
3. 百度语音开发文档 http://ai.baidu.com/docs#/ASR-API/top

### 支持平台
1. Android
2. iOS

### 安装
1. 本地安装
`cordova plugin add /your localpath --variable APIKEY=[your apikey] --variable SECRETKEY=[your secretkey] --variable APPID=[your appid]  `


### API使用
	//回调
	var response=function (res) {
        // res参数都带有一个type
        if (!res) {
          return;
        }

        switch (res.type) {
          case "asrReady": {
            // 识别工作开始，开始采集及处理数据
            $scope.$apply(function () {
              // TODO
            });
            break;
          }

          case "asrBegin": {
            // 检测到用户开始说话
            $scope.$apply(function () {
              // TODO
            });
            break;
          }

          case "asrEnd": {
            // 本地声音采集结束，等待识别结果返回并结束录音
            $scope.$apply(function () {
              // TODO
            });
            break;
          }

          case "asrText": {
            // 语音识别结果
            $scope.$apply(function () {
              var message = angular.fromJson(res.message);
              var results = message["results_recognition"];
            });
            break;
          }

          case "asrFinish": {
            // 语音识别功能完成
            $scope.$apply(function () {
              // TODO
            });
            break;
          }

          case "asrCancel": {
            // 语音识别取消
            $scope.$apply(function () {
              // TODO
            });
            break;
          }

          default:
            break;
        }

      }, function (err) {
         alert("语音识别错误");
      }
	  var error=function(err){
	  }
    // 语音识别内置ui事件监听
     cordova.plugins.bdasr.startSpeechUI(response,error);
    // 语音识别事件监听
     cordova.plugins.bdasr.startSpeechRecognize(response,error);

    // 主动结束语音识别
    cordova.plugins.bdasr.closeSpeechRecognize(response);

    // 主动取消语音识别
    cordova.plugins.bdasr.cancelSpeechRecognize(response);



