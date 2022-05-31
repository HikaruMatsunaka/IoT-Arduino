#include <M5StickCPlus.h>
#include <WiFi.h>

#define LED 10 //ポート10にLEDが接続されている

const char* ssid     = "PrototypingLab-G"; //各自の環境に設定
const char* password = "kobo12345"; //各自の環境に設定

const char* server_ip = "192.168.11.13"; //サーバのアドレス・各自の環境で設定
const int port = 20000;

WiFiClient client;

hw_timer_t *timer;
QueueHandle_t xQueue;
TaskHandle_t taskHandle;

float pitch;
float roll;
float yaw;

int counter;

const int sampleFrequency = 100;

// タイマー割り込み
void IRAM_ATTR onTimer() {
  int8_t data;

  // キューを送信
  xQueueSendFromISR(xQueue, &data, 0);
}

// 実際のタイマー処理用タスク
void task(void *pvParameters) {
  uint8_t calibration = 0;        // キャリブレーションの状態(0:初期化直後, 1:データ取得中, 2:完了)
  uint16_t calibrationCount = 0;  // データ取得数
  float gyroXSum = 0;             // ジャイロX軸の累計数
  float gyroYSum = 0;             // ジャイロY軸の累計数
  float gyroZSum = 0;             // ジャイロZ軸の累計数
  float gyroXOffset = 0;          // ジャイロX軸のオフセット
  float gyroYOffset = 0;          // ジャイロY軸のオフセット
  float gyroZOffset = 0;          // ジャイロZ軸のオフセット
  float pitchSum = 0;             // ピッチの累計数
  float rollSum = 0;              // ロールの累計数
  float yawSum = 0;               // ヨーの累計数
  float pitchOffset = 0;          // ピッチのオフセット
  float rollOffset = 0;           // ロールのオフセット
  float yawOffset = 0;            // ヨーのオフセット
  float gyroGain = 0;             // キャリブレーションが終わるまでは0

  while (1) {
    int8_t data;
    float accX;
    float accY;
    float accZ;
    float gyroX;
    float gyroY;
    float gyroZ;


    // タイマー割り込みがあるまで待機する
    xQueueReceive(xQueue, &data, portMAX_DELAY);

    // 加速度、ジャイロ取得
    M5.IMU.getAccelData(&accX, &accY, &accZ);
    M5.IMU.getGyroData(&gyroX, &gyroY, &gyroZ);

    // ジャイロ補正
    gyroX -= gyroXOffset;
    gyroY -= gyroYOffset;
    gyroZ -= gyroZOffset;

    // AHRS計算
    MahonyAHRSupdateIMU(gyroX * gyroGain, gyroY * gyroGain, gyroZ * gyroGain, accX, accY, accZ, &pitch, &roll, &yaw);

    // AHRS補正
    pitch -= pitchOffset;
    roll -= rollOffset;
    yaw -= yawOffset;

    // キャリブレーション
    if (calibration == 0) {
      // 最初の200個は読み捨てる
      calibrationCount++;
      if (200 <= calibrationCount) {
        calibration = 1;
        calibrationCount = 0;
      }
    } else if (calibration == 1) {
      // 一定時間データを取得してオフセットを計算する
      float gyro = abs(gyroX) + abs(gyroY) + abs(gyroZ);
      if (20 < gyro) {
        // 振動があった場合には再度キャリブレーション
        calibrationCount = 0;
        gyroXSum = 0;
        gyroYSum = 0;
        gyroZSum = 0;
        pitchSum = 0;
        rollSum = 0;
        yawSum = 0;
        //Serial.printf("Calibration Init!!!!! %f\n", gyro);
      } else {
        // 累計を保存
        gyroXSum += gyroX;
        gyroYSum += gyroY;
        gyroZSum += gyroZ;
        pitchSum += pitch;
        rollSum += roll;
        yawSum += yaw;
        calibrationCount++;
        if (500 <= calibrationCount) {
          // 一定数溜まったらオフセット計算
          calibration = 2;
          gyroXOffset = gyroXSum / calibrationCount;
          gyroYOffset = gyroYSum / calibrationCount;
          gyroZOffset = gyroZSum / calibrationCount;
          pitchOffset = pitchSum / calibrationCount;
          rollOffset = rollSum / calibrationCount;
          yawOffset = yawSum / calibrationCount;

          // 組み込みライブラリは25Hz動作なので実際のサンプリングレートとの比で調整する
          gyroGain = DEG_TO_RAD / (sampleFrequency / 25);
        }
      }
    } 
  }
}

void setup() {
  M5.begin();
  M5.IMU.Init();
  M5.Lcd.setRotation(0);  //Rotate the screen.
  M5.Lcd.setTextSize(2);  //Set font size. 

   //Wi-Fiへの接続
  M5.Lcd.print("Connecting to ");
  M5.Lcd.println(ssid);

  WiFi.begin(ssid, password); //ssidとpasswordを使って無線APに接続
  while (WiFi.status() != WL_CONNECTED) {//接続できたかのチェック
      delay(500);
      M5.Lcd.print(".");
  }
  M5.Lcd.println("");
  M5.Lcd.println("Successfully connected to WiFi.");
  M5.Lcd.println("IP address: ");
  M5.Lcd.println(WiFi.localIP());
  delay(1000);
  //サーバへのソケット接続

  M5.Lcd.fillScreen(BLACK); //画面をクリア
  M5.Lcd.setCursor(0, 0); //表示位置を指定
  M5.Lcd.print("Connecting to ");
  M5.Lcd.println(server_ip);
  while (!client.connected()) {
    client.connect(server_ip, port);
    delay(500);
    M5.Lcd.print("."); 
  }
  M5.Lcd.print("Successfully connected to server ");
  M5.Lcd.println(server_ip);

  M5.Imu.Init();  //IMUの初期化. 

  pinMode(10, OUTPUT);

  // キュー作成
  xQueue = xQueueCreate(1, sizeof(int8_t));

  // Core1の優先度5でタスク起動
  xTaskCreateUniversal(
    task,           // タスク関数
    "task",         // タスク名(あまり意味はない)
    8192,           // スタックサイズ
    NULL,           // 引数
    5,              // 優先度(大きい方が高い)
    &taskHandle,    // タスクハンドル
    APP_CPU_NUM     // 実行するCPU(PRO_CPU_NUM or APP_CPU_NUM)
  );

  // 4つあるタイマーの1つめを利用
  // 1マイクロ秒ごとにカウント(どの周波数でも)
  // true:カウントアップ
  timer = timerBegin(0, getApbFrequency() / 1000000, true);

  // タイマー割り込み設定
  timerAttachInterrupt(timer, &onTimer, true);

  // マイクロ秒単位でタイマーセット
  timerAlarmWrite(timer, 1000 * 1000 / sampleFrequency, true);

  // タイマー開始
  timerAlarmEnable(timer);


  //画面に表示
  M5.Lcd.fillScreen(BLACK);
  M5.Lcd.setTextColor(GREEN , BLACK);
  M5.Lcd.setRotation(3);
  M5.Lcd.setTextSize(2);

  counter = 0;
  
  
}

void loop() {
  M5.update(); //これを呼び出さないとボタンの状態は更新されない

  int btnA = M5.BtnA.wasPressed(); //A（ホーム）ボタンの状態を取得
  if (btnA == 1) { //ボタンの状態をチェック
    counter++; //カウンタの値を増やす

    //ここに音を鳴らす手引きを書きたい
    
    
  }
  M5.Lcd.setCursor(0, 50); //表示位置を指定
  M5.Lcd.print(counter); //カウンタ変数の値を出力

  //送信するデータの構築
  String str = String(pitch,2) + "," + String(roll,2) + "," + String(yaw,2) + ","+ String(counter,2); 
  client.println(str);//サーバにデータを送信


  //データの受信
  digitalWrite(LED, HIGH); //HIGHのとき消灯
  while(client.available()) {
        String recieved_data = client.readStringUntil('\n'); //サーバからのデータを受け取り
        recieved_data.trim();//先頭と末尾の改行とスペースを削除
        M5.Lcd.println(recieved_data); //画面に表示
        if(recieved_data == "LED"){
          digitalWrite(LED, LOW); //LOWのとき店頭
        }
  } 

  delay(50);
  
  // メイン処理は無し
  M5.Lcd.setCursor(0, 110);
  M5.Lcd.printf(" %5.2f, %5.2f, %5.2f   ", pitch, roll, yaw);

  delay(1);
  
}
