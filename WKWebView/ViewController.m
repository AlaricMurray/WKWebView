//
//  ViewController.m
//  WKWebView
//
//  Created by MyMac on 2016/11/23.
//  Copyright © 2016年 hengshuimofangkeji. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>
#import "OCJSHelper.h"



static CGFloat addViewHeight = 500;   // 添加自定义 View 的高度
static BOOL showAddView = YES;        // 是否添加自定义 View
static BOOL useEdgeInset = NO;        // 用那种方法添加自定义View， NO 使用 contentInset，YES 使用 div


@interface ViewController ()<WKNavigationDelegate,WKUIDelegate>
@property (nonatomic , strong)WKWebView * webView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) OCJSHelper *ocjsHelper;
@property (nonatomic, assign) CGFloat delayTime;
@property (nonatomic, assign) CGFloat contentHeight;
@property (nonatomic, strong) UIView *addView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = [[WKUserContentController alloc] init];
    // 交互对象设置
    [config.userContentController addScriptMessageHandler:(id)self.ocjsHelper name:@"timefor"];
    // 支持内嵌视频播放，不然网页中的视频无法播放
    config.allowsInlineMediaPlayback = YES;
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    self.ocjsHelper.webView = self.webView;
    [self.view addSubview:self.webView];
    
    
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    // 开始右滑返回手势
    self.webView.allowsBackForwardNavigationGestures = YES;
    
    NSURL *url = [self testurl];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
    
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, 2)];
    [self.view addSubview:self.progressView];
    self.progressView.progressTintColor = [UIColor greenColor];
    self.progressView.trackTintColor = [UIColor clearColor];
    
    NSKeyValueObservingOptions observingOptions = NSKeyValueObservingOptionNew;
    // KVO 监听属性，除了下面列举的两个，还有其他的一些属性，具体参考 WKWebView 的头文件
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:observingOptions context:nil];
    [self.webView addObserver:self forKeyPath:@"title" options:observingOptions context:nil];
    
    // 监听 self.webView.scrollView 的 contentSize 属性改变，从而对底部添加的自定义 View 进行位置调整
    [self.webView.scrollView addObserver:self forKeyPath:@"contentSize" options:observingOptions context:nil];
}

// 用来测试的一些url链接
- (NSURL *)testurl {
   // NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"html"];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"123" withExtension:@"html"];

    //   NSURL *url = [NSURL URLWithString:@"https://www.baidu.com"];
    //    NSURL *url = [NSURL URLWithString:@"https://github.com/"];
    //    NSURL *url = [NSURL URLWithString:@"https://z.yeemiao.com/share/share.html"]; // 自建证书，在iOS8下面，无法通过验证
    return url;
}

-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    NSLog(@"starting");
}
-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    NSLog(@"did loaded");
}
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    NSLog(@"finishing");
    if (!showAddView) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        self.addView = [[UIView alloc] initWithFrame:CGRectMake(0, self.webView.scrollView.contentSize.height, self.view.frame.size.width, addViewHeight)];
        self.addView.backgroundColor = [UIColor redColor];
        [self.webView.scrollView addSubview:self.addView];
        
        if (useEdgeInset) {
            // url 使用 test.html 对比更明显
            self.webView.scrollView.contentInset = UIEdgeInsetsMake(64, 0, addViewHeight, 0);
        } else {
            NSString *js = [NSString stringWithFormat:@"\
                            var appendDiv = document.getElementById(\"AppAppendDIV\");\
                            if (appendDiv) {\
                            appendDiv.style.height = %@+\"px\";\
                            } else {\
                            var appendDiv = document.createElement(\"div\");\
                            appendDiv.setAttribute(\"id\",\"AppAppendDIV\");\
                            appendDiv.style.width=%@+\"px\";\
                            appendDiv.style.height=%@+\"px\";\
                            document.body.appendChild(appendDiv);\
                            }\
                            ", @(addViewHeight), @(self.webView.scrollView.contentSize.width), @(addViewHeight)];
            [self.webView evaluateJavaScript:js completionHandler:nil];
        }
    });

}
- (void)dealloc {
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.webView removeObserver:self forKeyPath:@"title"];
    [self.webView removeObserver:self forKeyPath:@"contentSize"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        [self.progressView setProgress:self.webView.estimatedProgress animated:YES];
        if (self.webView.estimatedProgress < 1.0) {
            self.delayTime = 1 - self.webView.estimatedProgress;
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.progressView.progress = 0;
        });
    } else if ([keyPath isEqualToString:@"title"]) {
        self.title = self.webView.title;
    } else if ([keyPath isEqualToString:@"contentSize"]) {
        if (self.contentHeight != self.webView.scrollView.contentSize.height) {
            self.contentHeight = self.webView.scrollView.contentSize.height;
            self.addView.frame = CGRectMake(0, self.contentHeight - addViewHeight, self.view.frame.size.width, addViewHeight);
            NSLog(@"----------%@", NSStringFromCGSize(self.webView.scrollView.contentSize));
        }
    }
}

-(void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    NSLog(@"fail");
}

// 在发送请求之前，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"decidePolicyForNavigationAction   ====    %@", navigationAction);
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 在收到响应后，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSLog(@"decidePolicyForNavigationResponse   ====    %@", navigationResponse);
    decisionHandler(WKNavigationResponsePolicyAllow);
}

// 加载HTTPS的链接，需要权限认证时调用
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if ([challenge previousFailureCount] == 0) {
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        } else {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
    } else {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
}

#pragma mark - WKUIDelegate

// 提示框
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示框" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler();
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
}

// 确认框
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认框" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
}

// 输入框
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * __nullable result))completionHandler {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"输入框" message:prompt preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.textColor = [UIColor blackColor];
        textField.placeholder = defaultText;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler([[alert.textFields lastObject] text]);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(nil);
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
}

#pragma mark - Setter & Getter

- (OCJSHelper *)ocjsHelper {
    if (!_ocjsHelper) {
        _ocjsHelper = [[OCJSHelper alloc] initWithDelegate:(id)self vc:self];
    }
    return _ocjsHelper;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
