package org.apache.cordova.bdasr;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.widget.Toast;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.LOG;
import org.apache.cordova.CallbackContext;

import org.apache.cordova.PermissionHelper;
import org.apache.cordova.PluginResult;
import org.apache.cordova.bdasr.core.recog.IStatus;
import org.apache.cordova.bdasr.core.recog.MyRecognizer;
import org.apache.cordova.bdasr.core.recog.listener.ChainRecogListener;
import org.apache.cordova.bdasr.core.recog.listener.MessageStatusRecogListener;
import org.apache.cordova.bdasr.ui.BaiduASRDigitalDialog;
import org.apache.cordova.bdasr.ui.DigitalDialogInput;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.LinkedHashMap;
import java.util.Map;

import com.baidu.speech.EventListener;
import com.baidu.speech.EventManager;
import com.baidu.speech.EventManagerFactory;
import com.baidu.speech.asr.SpeechConstant;


/**
 * This class echoes a string called from JavaScript.
 */
public class bdasr extends CordovaPlugin implements EventListener {
    
    private EventManager asr;
    private static CallbackContext pushCallback;
    private static CallbackContext bdCallback=null;
    private String permission = Manifest.permission.RECORD_AUDIO;
    
    public static final String TAG = "BaiduAsrPlugin";
    
    
    
    private DigitalDialogInput input;
    private ChainRecogListener chainRecogListener;
    private MyRecognizer myRecognizer;
    private Handler handler;
    
    
    private Context getApplicationContext() {
        return this.cordova.getActivity().getApplicationContext();
    }
    
    protected void getMicPermission(int requestCode) {
        PermissionHelper.requestPermission(this, requestCode, permission);
    }
    
    
    public void onRequestPermissionResult(int requestCode, String[] permissions,
                                          int[] grantResults) throws JSONException {
        for (int r : grantResults) {
            if (r == PackageManager.PERMISSION_DENIED) {
                Toast.makeText(getApplicationContext(), "用户未授权[TSM]使用麦克风", Toast.LENGTH_LONG).show();
                return;
            }
        }
        
    }
    
    @Override
    protected void pluginInitialize() {
        super.pluginInitialize();
        
        asr = EventManagerFactory.create(getApplicationContext(), "asr");
        asr.registerListener(this);
        
        
        handler = new Handler() {
            @Override
            public void handleMessage(Message msg) {
                super.handleMessage(msg);
                handleMsg(msg);
            }
        };
        chainRecogListener = new ChainRecogListener();
        // DigitalDialogInput 输入 ，MessageStatusRecogListener可替换为用户自己业务逻辑的listener
        chainRecogListener.addListener(new MessageStatusRecogListener(handler));
        myRecognizer = new MyRecognizer(webView.getContext(), chainRecogListener);
    }
    protected void handleMsg(Message msg) {
    	if (msg.what == IStatus.STATUS_FINISHED){
			sendEvent("asrFinish", msg.obj.toString());
    	}
    }
    @Override
    public void onPause(boolean multitasking) {
        super.onPause(multitasking);
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        if (null != asr) {
            asr = null;
        }
    }
    
    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        
        
        if ("startSpeechRecognize".equals(action)) {
            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    
                    startSpeechRecognize();
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
                }
            });
        } else if ("closeSpeechRecognize".equals(action)) {
            // 停止录音
            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    asr.send(SpeechConstant.ASR_STOP, null, null, 0, 0);
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
                }
            });
            
        } else if ("cancelSpeechRecognize".equals(action)) {
            cordova.getThreadPool().execute(new Runnable() {
                @Override
                public void run() {
                    asr.send(SpeechConstant.ASR_CANCEL, "{}", null, 0, 0);
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
                }
            });
        } else if ("addEventListener".equals(action)) {
            cordova.getThreadPool().execute(new Runnable() {
                @Override
                public void run() {
                    pushCallback = callbackContext;
                    addEventListenerCallback(callbackContext);
                }
            });
        } else if ("startSpeechUI".equals(action)) {
        	LOG.i(TAG, action);
        	startSpeechUI(callbackContext);

        } else {
            Log.e(TAG, "Invalid action : " + action);
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.INVALID_ACTION));
            return false;
        } 
        
        return true;
    }
    
    private void startSpeechRecognize() {
        
        if (PermissionHelper.hasPermission(this, permission)) {
            Map<String, Object> params = new LinkedHashMap<String, Object>();
            String event = SpeechConstant.ASR_START; // 替换成测试的event
            
            params.put(SpeechConstant.ACCEPT_AUDIO_VOLUME, false);
            // params.put(SpeechConstant.NLU, "enable");
            // params.put(SpeechConstant.VAD_ENDPOINT_TIMEOUT, 0); // 长语音
            // params.put(SpeechConstant.IN_FILE, "res:///com/baidu/android/voicedemo/16k_test.pcm");
            // params.put(SpeechConstant.VAD, SpeechConstant.VAD_DNN);
            // params.put(SpeechConstant.PROP ,20000);
            // params.put(SpeechConstant.PID, 1537); // 中文输入法模型，有逗号
            // 请先使用如‘在线识别’界面测试和生成识别参数。 params同ActivityRecog类中myRecognizer.start(params);
            String json = new JSONObject(params).toString(); // 这里可以替换成你需要测试的json
            asr.send(event, json, null, 0, 0);
        } else {
            getMicPermission(0);
        }
        
    }
    
    private void addEventListenerCallback(CallbackContext callbackContext) {
        
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);
        
    }
    
    //   EventListener  回调方法
    @Override
    public void onEvent(String name, String params, byte[] data, int offset, int length) {
        
        if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_READY)) {
            // 引擎就绪，可以说话，一般在收到此事件后通过UI通知用户可以说话了
            sendEvent("asrReady", "ok");
        }
        
        if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_BEGIN)) {
            // 检测到说话开始
            sendEvent("asrBegin", "ok");
        }
        
        if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_END)) {
            // 检测到说话结束
            sendEvent("asrEnd", "ok");
        }
        
        if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_FINISH)) {
            // 识别结束（可能含有错误信息）
            try {
                JSONObject jsonObject = new JSONObject(params);
                int errCode = jsonObject.getInt("error");
                
                if (errCode != 0) {
                    sendError("语音识别错误");
                } else {
                    sendEvent("asrFinish", "ok");
                }
                
            } catch (JSONException e) {
                Log.i(TAG, e.getMessage());
            }
            
            
        }
        
        if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_PARTIAL)) {
            // 识别结果
            sendEvent("asrText", params);
        }
        
        if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_CANCEL)) {
            sendEvent("asrCancel", "ok");
        }
        
    }
    
    
    private void sendEvent(String type, String msg) {
        JSONObject response = new JSONObject();
        try {
            response.put("type", type);
            response.put("message", msg);
            
            final PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, response);
            pluginResult.setKeepCallback(true);
            if (pushCallback != null) {
                pushCallback.sendPluginResult(pluginResult);
            }
            
        } catch (JSONException e) {
            Log.i(TAG, e.getMessage());
        }
    }
    
    private void sendError(String message) {
        JSONObject err = new JSONObject();
        try {
            err.put("type", "asrError");
            err.put("message", message);
            
            PluginResult pluginResult = new PluginResult(PluginResult.Status.ERROR, err);
            pluginResult.setKeepCallback(true);
            if (pushCallback != null) {
                pushCallback.sendPluginResult(pluginResult);
            }
            
        } catch (JSONException e) {
            Log.i(TAG, e.getMessage());
        }
        
        
    }
    private void startSpeechUI(CallbackContext callbackContext){
    	bdCallback = callbackContext;
    	Map<String, Object> params = new LinkedHashMap<String, Object>();
//        params.put("pid",1536);
    	params.put(SpeechConstant.ACCEPT_AUDIO_VOLUME, true);
//        params.put(SpeechConstant.PID, 1536);
        params.put(SpeechConstant.VAD_ENDPOINT_TIMEOUT, 0);
        input = new DigitalDialogInput(myRecognizer, chainRecogListener, params);
        BaiduASRDigitalDialog.setInput(input); // 传递input信息，在BaiduASRDialog中读取,
        Intent intent = new Intent(webView.getContext(), BaiduASRDigitalDialog.class);
        this.cordova.getActivity().startActivityForResult(intent, 2);
    }
    
    
}

