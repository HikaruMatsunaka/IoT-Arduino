// Smaaviltguiden - shooting game 
// 25.09.2017
// By: Martin Andersen | @webmaeistro

import processing.net.*; //
int port = 20000;//サーバのポート番号を指定（今回は20000）
int myFrameRate = 30; //フレームレート
Server my_server; //サーバオブジェクト用の大域変数

float pitch = 0;
float roll = 0;
float yaw = 0;
int btnA = 0;

PImage backgroundImg;
PImage duck;
PImage shotgun;
PImage bullet;
PImage goldenduck;
PImage duckhuntingbeginningscreen;
PImage explosion;
PImage roastduck;

  int state=2, stage = 1, numBullets = 5, lastClear = 0, lastReload = 0, stageFrame = 0, lives = 5, score, highscore, timeLeft;
boolean dead = false;
boolean shoot = false;
boolean goldDuckShot = false;
void setup() {
  
   my_server = new Server(this, port); //サーバを立ち上げる
  if(my_server.active() == true){ //サーバが正しく立ち上がったか確認
    println("create server");
  }
  


  size(1200,700, P2D); 
  //orientation(LANDSCAPE);  
  translate(width/2,height/2);
backgroundImg = loadImage("duck_decoys.jpg");
  duck = loadImage("mallard.png");
  shotgun = loadImage("doublebarrel.png");
  bullet = loadImage("shell.png");
  goldenduck = loadImage("wd.png");
  duckhuntingbeginningscreen = loadImage("smaaviltguiden.jpg");
  explosion = loadImage("fire.png");
  roastduck = loadImage("mallard2.png");
  noCursor();
}
class Duck {
  boolean flip = false;
  boolean bull = false;
  boolean shot = false;
  float vx;
  float xDuck, yDuck;
  float murpx, murpy;
  int count = 1;
  Duck(int x, int y, boolean toflip) {
    flip = toflip;
    xDuck = x;
    vx = stage;
    yDuck = y;
  }
  void display() {

    if (flip) { 
      pushMatrix();
      if (shot)image(roastduck, xDuck, yDuck);
      else { 
        //scale(-1.0, 1.0);
        image(duck, -xDuck, yDuck);
      }
      popMatrix();
      xDuck-=vx;
    }
    else {
      pushMatrix();
      if (shot)image(roastduck, xDuck, yDuck);
      else image(duck, xDuck, yDuck);
      popMatrix();
      xDuck+=vx;
    }
    if (shot)yDuck+=15;


    if (shot&&count<20) {
      count++;
      vx=0;
      image(explosion, murpx, murpy);
    }
  }
}
class Goduck {
  boolean flip = false;
  boolean shot = false;
  float vx;
  float xDuck1, yDuck1;
  Goduck(int x, int y) {
    xDuck1 = x;
    vx=stage*2;
    yDuck1 = y;
  }
  void display() {
    if (shot) {
      yDuck1+=15;
      vx=0;
    }
    if (flip) { 
      pushMatrix();
   //   scale(-1.0, 1.0);
      image(goldenduck, -xDuck1, yDuck1);
      popMatrix();
      xDuck1-=vx;
    }
    else {
      pushMatrix();
      image(goldenduck, xDuck1, yDuck1);
      popMatrix();
      xDuck1+=vx;
    }
  }
}
ArrayList <Duck> ducks = new ArrayList<Duck>();
ArrayList <Goduck> ducks1 = new ArrayList<Goduck>();
//ArrayList<PImage> images = new ArrayList<PImage>();
//images.add(loadImage("thefile.png"));
//images.add(loadIMage("asdfasdf"));
//PImage bla = images.get(0);ad
//image(images.get(0),  123, 234 );
ArrayList <PImage> bullets = new ArrayList<PImage>(); 
void draw() {
  
  Client c = my_server.available();//通信してきたクライアントを取得
  while(c != null){ //通信してきたすべてのクライアントを処理
    String msg = c.readStringUntil('\n'); //クライアントからのメッセージを読み込む
    if (msg != null){ //メッセージが存在していたら
      // *** クライアントから受け取ったメッセージの処理 [ここから] ***
      msg = msg.trim(); //メッセージの最後の改行文字\nを削除
      println("server to client" + c.ip() + "message: " + msg);//コンソールにメッセージを出力
      // クライアントから受け取ったメッセージの処理を記述
      String[] data = splitTokens(msg,","); //データを分割
      //受け取ったデータを変数に代入
      pitch = ((float(data[0])+90)/180)*700;
      roll = -((float(data[1])-90)/180)*700;
      yaw = ((float(data[2])+90)/180)*1200;
      btnA = int(data[3]);
       }
    c = my_server.available(); //待っている次のクライアントを取得
  }
      
  if (state == 0) {
    timeLeft=(int)(20-(((frameCount-stageFrame)%1200)/60));
    if (lives<=0) {
      image(duckhuntingbeginningscreen, 0, 0);
      textSize(40);
      text("You Lose", width/2, height/2);
      lives=0;
      if (btnA==1) {
        ducks.clear();
        score = 0;
        lives = 5;
        numBullets = 5;
        stage = 1;
        stageFrame=0;
        lastReload = 0;
        lastClear = 0;
        frameCount = 0;
        goldDuckShot= false;
        ducks1.get(0).vx=stage*2;
      }
    }
    else {
      if (frameCount%(120-(10*stage))==0) {
        int derpx;
        int derpy = (int)random(0, 500);
        boolean derpsplit;
        if (random(0, 2)>1) {
          derpx=700;
          derpsplit = true;
        }
        else {
          derpx=0;
          derpsplit = false;
        }
        ducks.add(new Duck(derpx, derpy, derpsplit));
      }
      image(backgroundImg, 0, 0);
      if ((frameCount-stageFrame)%1200==600) {
        ducks1.add(new Goduck(0, (int)random(0, height-50)));
      }
      if ((frameCount-stageFrame)%1200>600) {
        if (ducks1.size()>0) {
          ducks1.get(0).display();
          if (goldDuckShot==false&&btnA==1&&dist(pitch, roll, ducks1.get(0).xDuck1, ducks1.get(0).yDuck1)<60&&lives>0) {
            goldDuckShot=true;
            score+=stage*10;
            ducks1.get(0).shot=true;
          }
        }
      }
      for (int i=0;i<ducks.size();i++) {
        ducks.get(i).display();
        if (ducks.get(i).bull) {
          fill(0);
          text("Perfect!", ducks.get(i).xDuck, ducks.get(i).yDuck);
        }
        if (700<ducks.get(i).xDuck||ducks.get(i).xDuck<0) {
          lives--;
          ducks.remove(i);
        }
      }
      if (score>=highscore) {
        highscore=score;
      }
      image(shotgun, pitch-52, roll-52);
      if ((frameCount - stageFrame)%1200==0) {
        state = 1;
      }
      fill(25);
      textSize(20);
      textAlign(RIGHT);
      text("Level: "+stage, width-10, 12);
      text("score: "+score, width-10, 50);
      text("life: "+lives, width-10, 70);
      text("Top score: "+highscore, width-10, 30);
      text("Time: "+timeLeft, width-10, 90);
      //textAlign(LEFT);
      //image(bullet,0,540);
      //text("Bullets: "+numBullets, 10, 590);
      for (int j = 0 ; j < numBullets; j++) {
        if (state==0) {
          image(bullet, j*10+10, 540);
        }
      }
    }
  }
  if (state == 2) {
     background(0);
    image(duckhuntingbeginningscreen, 0, 0, 1200, 720);
    textSize(18);
    fill(255);
    text ("Shoot the birds to score points.", 530, 300);
    text ("The higher the stage, the faster the ducks move and the more points they're worth", 530, 350);
    text ("Life is 5.", 530, 400);
    text ("Press B to reload.", 530, 450);
    text ("Click to start.", 530, 600);
   // text("1) Shoot the ducks to get points. The higher the stage, the faster the ducks move and the more points they're worth", width/2, height/2+170);
 //   text("2) You have 5 lives. If you miss a duck, you lose a life. Don't let your lives run out!", width/2, height/2+180);
   // text("3) Press r to reload; it takes a second to reload", width/2, height/2+190);
   // text("4) Space is available every 7 seconds and it clears all ducks except the golden duck, but doesn't give any points", width/2, height/2+200);
    //text("5) Shoot accurately for a bulleye!", width/2, height/2+210);
    //text("6) Hit the golden duck for a lot of points!", width/2, height/2+220);
    if (mousePressed) {
      frameCount = 0;
      state = 0;
    }
  }
  if (state==1) {
    background(0);
    textAlign(CENTER);
    fill(255);
    textSize(50);
    text("Level " + (stage+1), width/2, height/2);
    text("Press A button to start.", width/2, height/2+50);
    lives = 5;
    if (btnA==1&&(frameCount-stageFrame)>=1200) {
      ducks.clear();
      stageFrame = 1;
      frameCount=1;
      lives = 5;
      numBullets = 5;
      stage++;
      goldDuckShot=false;
      ducks1.remove(0);
      state = 0;
    }
  }
}
void keyPressed() {
  if (key==' ' && (frameCount - lastClear) > 60*7) {
    ducks.clear();
    lastClear = frameCount;
  }
  if (key=='r') {
    lastReload = frameCount;
    numBullets = 5;
  }
  
}
void deviceShake() {
      lastReload = frameCount;
    numBullets = 5;
    }
    
void sendDataToAllClients(){
  //送信するメッセージを作成
  String msg = "LED" + "\n"; //データをカンマで区切り、最後に改行コードを付加
  // *** クライアントにメッセージを送信 ***//
  my_server.write(msg);//接続しているすべてのクライアントにメッセージを送る
  println("サーバがすべてのクライアントにメッセージを送信：" + msg);//コンソールに表示
}    
    
void mousePressed() {
  if (frameCount - lastReload>=25) {
    if (numBullets > 0) {
      numBullets--;
      for (int i=0;i<ducks.size();i++) {
        if (dist(pitch, roll, ducks.get(i).xDuck, ducks.get(i).yDuck+50)<100&&dist(pitch, roll, ducks.get(i).xDuck, ducks.get(i).yDuck+50)>20&&lives>0) {
          score+=stage;
          ducks.get(i).murpx=ducks.get(i).xDuck;
          ducks.get(i).murpy=ducks.get(i).yDuck;
          ducks.get(i).shot=true;

          if (ducks.get(i).yDuck>600) {
            ducks.remove(i);
          }
        }
        else if (dist(pitch, roll, ducks.get(i).xDuck, ducks.get(i).yDuck+50)<20&&dist(pitch, roll, ducks.get(i).xDuck-50, ducks.get(i).yDuck)>0&&lives>0) {
          score+=stage;
          ducks.get(i).murpx=ducks.get(i).xDuck;
          ducks.get(i).murpy=ducks.get(i).yDuck;
          ducks.get(i).shot=true;
          ducks.get(i).bull=true;
          if (ducks.get(i).yDuck>600) {
            ducks.remove(i);
          }
        }
      }
    }
  }
  sendDataToAllClients();
}
