// rogerio.bego@hotmail.com
String versao="1.2";
// 29/01/2017 - v1.2 coloquei um valor para o trigger 0-1024 (0-5v)
//               transmitir  tv512.  (512=2.5v)
// 15/10/2015 - acrescentei mais um canal - 4canais
// 16/09/2015 - devido a falta de memória no garagino, 
//              mudei o array de int para byte,
//              então, dividi os valores por 4 (1023/4=255)
// garaginoscopio v1 08/09/2015

//constantes para a classe Dial
byte escLinear=0; // Dial com escala linear
byte escLog=1;     // Dial com escala logarítimica (base 10)
byte altMove=2; // mudar o valor ao arrastar o mouse "MouseDragged"
byte altSolta=3; // mudar o valor ao soltar o botão do mouse "MouseReleased"
boolean nInt=true; // n é inteiro (arredondar), ou decimal !nInt 
boolean fmt=true; // fmt=true="formatar",  !fmt=false="não formatar"
boolean esperandoTrigger=false;
int vTrigger=0; // valor do trigger (subindo) 0-1024 (0-5v) 

color cor[]={color(255, 0, 0), color(0, 255, 0), color(0, 0, 255), color(255,255,0)}; // canais: red,green,blue,yellow

import processing.serial.*;

// configuração dos objetos
Serial port;
Com com;
Tela tela;
CanalXYZ chXYZ;

Botao resetEixos;
Botao resetMedir;
Canal canal[]=new Canal[4];
Grupo grupo[]=new Grupo[3]; // usado para alterar v/div e ms/div simultaneamente em todos os canais usando SHIFT
// painel para os controles de Amostragem
Painel pnlAmostra; // painel
Dial dt; // delta t (tempo de cada leitura)
Dial q;  // quantidade de leituras 
Botao umaAmostra; // solicita uma Amostra
Botao variasAmostras; // solicita várias Amostras
Botao fluxoContinuo;  // entra com leitura a cada dt
FmtNum tTotal; // tempo total da amostragem dt*q

Botao demo[]=new Botao[3]; // botões para gerar sinais de demonstração
float fase1, fase2, t1, t2; // fase dos DEMO //para noise(t) do demo
CheckBox verPontos; // ver os pontos da amostragem
CheckBox calcFreq; // detectar frequencia
CheckBox grafDif; // (ver) mostrar gráfico Diferença (parecido com a derivada)

//Dial ruido; // usado para melhorar a detecção da frequencia

// painel para medir resistor/capacitor
Painel pnlRC; // o valor é colocado em tex2 do CheckBox RC 
CheckBox RC; // ativa/desativa medidor de resistor/capacitor

// painel para o Gerador de Sinal
Painel pnlSinal;
CheckBox sinal; // f e t são dependentes f=1/t, t=1/f
Dial fSinal;    // f (frequencia) do Sinal (10kHz-0.125Hz) 
Dial tSinal;    // T (período) do Sinal (100us-8s)
Dial tonSinal;  // tempo em ON (0-100%)

// verificar se o tempo de leitura Real é igual ao desejado
FmtNum tTotalReal, dtReal; // tempos reais de leitura enviados pelo garagino
boolean dtErro=false;
float Q=45.0; //tamanho do quadrado na tela

//temporarios
int marg1, marg2; //margem temporaria para ajustar a posição dos objetos

void setup() {
  size(850, 700); 
  //size(800,700);
  frameRate(10);
  
  // inicialização dos objetos 
  tela=new Tela(30+10, 60, 13*Q, 12*Q);  //horizontal 10divisoes , vertical 12divisoes
  
  marg1=tela.x+tela.w+10; 
  marg2=marg1+200;
  
  //com=new Com(port, tela.x+tela.w-175, tela.y-30, 175, 20);
  com=new Com(port, tela.x+tela.w-400, tela.y-30, 400, 20);

  for (byte k=0; k<3; k++){ // deve estar antes do canal
     grupo[k]=new Grupo(); 
  }

  resetEixos=new Botao("Axes",marg1+50,tela.y,60,20);
  resetMedir=new Botao("Measure",resetEixos.x+resetEixos.w+2,tela.y,60,20);

  //demo & canais
  for (byte k=0; k<4; k++) {
    if (k<3) {demo[k]=new Botao(str(k+1), marg1+50+k*30, tela.y/2-10, 30, 20);}
    
    canal[k]=new Canal(k, cor[k], marg1, tela.y+27+k*110, 185, 100); 
  }
  
  //chXYZ
  chXYZ=new CanalXYZ(color(255,0,255),marg1,canal[3].y+canal[3].h+10,185,80);
  chXYZ.verCanais.clicado=true;
  
  verPontos=new CheckBox("Show dots", chXYZ.x, chXYZ.y+chXYZ.h+5, 15);
  calcFreq=new CheckBox("Detect freq.", verPontos.x, verPontos.y+verPontos.h+5, 15);
  grafDif=new CheckBox("Show freq.",calcFreq.x,calcFreq.y + calcFreq.h + 5, 15);

  //medidor de resistor/capacitor
  pnlRC=new Painel("", tela.x, tela.y+tela.h+10, 125, 40);
  RC=new CheckBox("Measure R, C", pnlRC.x, pnlRC.y, 15);

  //Gerador de Sinais - agora só gera onda quadrada, depois vai gerar triangulo, denteDeSerra, e senidal
  pnlSinal=new Painel("", pnlRC.x+pnlRC.w+10, pnlRC.y, 150, 85);
  sinal=new CheckBox("Signal Generator", pnlSinal.x, pnlSinal.y, 15);
  fSinal=new Dial(escLog, altSolta, !nInt, fmt, "f", "Hz", 10f, 125e-3f, 10e3f, pnlSinal.x+5, sinal.y+sinal.h+2, pnlSinal.w-10, 20);
  tSinal=new Dial(escLog, altSolta, !nInt, fmt, "T", "s", 100e-3f, 100e-6f, 8f, fSinal.x, fSinal.y+fSinal.h+2, fSinal.w, fSinal.h);
  tonSinal=new Dial(escLinear, altSolta, nInt, !fmt, "Duty", "%", 50f, 0f, 100f, tSinal.x, tSinal.y+tSinal.h+2, tSinal.w, tSinal.h);

  // posicionamento da Amostragem 
  pnlAmostra=new Painel("Record time", pnlSinal.x+pnlSinal.w+10, pnlSinal.y, 260, 85);
  dt=new Dial(escLog, altSolta, nInt, fmt, "dt", "s", 1e-3f, 10e-6f, 2f, pnlAmostra.x+5, pnlAmostra.y+20, 100, 20);
  dtReal=new FmtNum(0,nInt,fmt);
  q=new Dial(escLinear, altSolta, nInt, !fmt, "qty", "", 100, 1, 100, dt.x+dt.w+5, dt.y, 60, 20);
  tTotal=new FmtNum(dt.v.getV()*q.v.getV(), !nInt);
  tTotalReal=new FmtNum(0,!nInt);
  umaAmostra=new Botao("One", dt.x, dt.y+dt.h+5, 80, 20);
  variasAmostras=new Botao("Various", umaAmostra.x+umaAmostra.w+5, umaAmostra.y, umaAmostra.w, umaAmostra.h);
  fluxoContinuo=new Botao("Continous", variasAmostras.x+variasAmostras.w+5, variasAmostras.y, variasAmostras.w, variasAmostras.h);
  


}

void draw() {
  //==== Construir a tela e mostrar os controles =========
  background(100);
  fill(0, 255, 255); 
  textAlign(LEFT, TOP);
  textSize(24); 
  text("BegOscopio "+versao, tela.x, 12);
  fill(0); 
  textSize(12); 
  text("rogerio.bego@hotmail.com", tela.x, tela.y-15);
  tela.display();
  // Botões de demonstração
  textSize(15);
  fill(0); 
  textAlign(RIGHT, CENTER); 
  text("DEMO", demo[0].x-5, demo[0].y+demo[0].h/2); //tela.x+tela.w+10,tela.y);
  text("RESET",resetEixos.x-5,resetEixos.y+resetEixos.h/2);
  //text("medir", medir[0].x-5,medir[0].y+medir[0].h/2);
  //text("trigger", trigger[0].x-5,trigger[0].y+trigger[0].h/2);
  chXYZ.display();
  //XYZ.display();
  //for (byte k=0; k<3;k++){
  //  selXYZ[k].display();
  //}
  for (byte k=0; k<4; k++) {
    if (k<3){demo[k].display();}
    //medir[k].display();
    //trigger[k].display();
    canal[k].display();
  }
  //medir[4].display();
  //trigger[4].display();
  verPontos.display();
  calcFreq.display();
  grafDif.display();
  //ruido.display();
  com.display();
  resetEixos.display();
  resetMedir.display();

  tTotal.setV(dt.v.getV()*q.v.getV());
  pnlAmostra.tex2="("+tTotal.printV()+"s)";
  pnlAmostra.display();
  dt.display();
  q.display();  
  umaAmostra.display();
  variasAmostras.display();
  fluxoContinuo.display();
  //== mostrar o dtReal, tTotalRea e o erro
  textAlign(LEFT);
  if (dtErro){ fill(255,0,0); } else {fill(0,20,0); }
  String tex="Real: dt"+dtReal.printV()+"s";
  if (fluxoContinuo.clicado==false){
     tex+="  total"+tTotalReal.printV()+"s"; 
  }
  text(tex,pnlAmostra.x+5,pnlAmostra.y+pnlAmostra.h-2);
  fill(0);
  //text("tTotal "+tTotalReal.printV(),pnlSinal.x+pnlSinal.w+10,pnlSinal.y+40);
  

  pnlRC.display();
  RC.display();

  pnlSinal.display();
  sinal.display();
  fSinal.display();
  tSinal.display();
  tonSinal.display();

  //=== se DEMO estiver ativado, então, gerar os dados ===
  if (demo[0].clicado){
        float mf=second()/10; // de 10 em 10 segundos faz multiplos da frequencia mf*freq
        for (int k=0; k<q.v.v; k++){
           canal[0].buffer[k]=(int)(512.0*(1+sin(2.0*PI*fSinal.v.v*((float)k*dt.v.v)))); 
           canal[1].buffer[k]=(int)(512.0*(1+sin(fase1+2.0*PI*tonSinal.v.v/10.0*fSinal.v.v*((float)k*dt.v.v))));
           canal[2].buffer[k]=(canal[0].buffer[k]+canal[1].buffer[k])/2;
           canal[3].buffer[k]=(int)(512.0*(1+sin(2.0*PI*fSinal.v.v*(k*dt.v.v)+sin(2*PI*mf*fSinal.v.v*(k*dt.v.v)))));
           //t+=0.002;
         }
           fase1+=2*PI/100;
        canal[0].atualizou=true;
        canal[1].atualizou=true;
        canal[2].atualizou=true;
        canal[3].atualizou=true;
  } else if (demo[1].clicado){
        //float mf=second()/10+1; // de 10 em 10 segundos faz multiplos da frequencia mf*freq
        //float qmax=1.0/(2*dt.v.v*fSinal.v.v);
        float qmax=1/(fSinal.v.v*2*dt.v.v);
        float qmin=qmax*tonSinal.v.v/100.0;
        float qc=0.0;
        float fator=0;
        float vq=0;
        
        float f0=(fase1/(2.0*PI*fSinal.v.v*dt.v.v))%qmax;
        float f1=((fase1+radians(120))/(2.0*PI*fSinal.v.v*dt.v.v))%qmax;
        float f2=((fase1+radians(240))/(2.0*PI*fSinal.v.v*dt.v.v))%qmax;
        
        
        for (int k=0; k<q.v.v; k++){
           qc=k % qmax;
           if (qc<qmin) fator=0; else fator=1.0;
           
           //println("k=",k," qc=",qc," qmin=",qmin," qmax=",qmax, " fase1=",(fase1/(2.0*PI*fSinal.v.v*dt.v.v))%qmax);
           //(fase1/(2PIdt))%qmax=",(fase1/(2.0*PI*dt.v.v))%qmax);

           t2=((float)k+f0) % qmax;
           if (t2<qmin) vq=0; else vq=1.0;
           canal[0].buffer[k]=(int)(vq*512.0*(sin(fase1+2.0*PI*fSinal.v.v*((float)k*dt.v.v))));
           canal[3].buffer[k]=(int)(vq*1023.0);

           t2=((float)k+f1)%qmax;
           if (t2<qmin) vq=0; else vq=1.0;
           canal[1].buffer[k]=(int)(vq*512.0*(sin(fase1+radians(120)+2.0*PI*fSinal.v.v*((float)k*dt.v.v))));
           
           t2=((float)k+f2)%qmax;
           if (t2<qmin) vq=0; else vq=1.0;
           canal[2].buffer[k]=(int)(vq*512.0*(sin(fase1+radians(240)+2.0*PI*fSinal.v.v*((float)k*dt.v.v)))); 
     
           
         }
           
           
        canal[0].atualizou=true;
        canal[1].atualizou=true;
        canal[2].atualizou=true;
        canal[3].atualizou=true;
      
  } else if (demo[2].clicado){
        //float mf=second()/10+1; // de 10 em 10 segundos faz multiplos da frequencia mf*freq
        float qmax=1.0/(2*dt.v.v*fSinal.v.v);
        float qmin=qmax*tonSinal.v.v/100.0;
        float qc=0.0;
        float fator=0;
        for (int k=0; k<q.v.v; k++){
           qc=k % qmax;
        //   println(k," qc=",qc);
           if (qc<qmin) fator=1; else fator=0;
           canal[0].buffer[k]=(int)(fator*1023.0); 
           if (qc<qmin) {
             canal[1].buffer[k]=(int)(512.0*(1.0-exp(-qc*100.0*dt.v.v)));
           } else {
             canal[1].buffer[k]=(int)(512.0*(exp(-(qc-qmin+1)*100.0*dt.v.v)));
           }
           canal[2].buffer[k]=(int)(512.0+512.0*(sin(radians(240)+2.0*PI*fSinal.v.v*((float)k*dt.v.v)))); 
          
           canal[3].buffer[k]=(int)(fator*512.0*(sin(2.0*PI*fSinal.v.v*((float)k*dt.v.v)))); 
          
         }
           fase1+=2*PI/100;
        canal[0].atualizou=true;
        canal[1].atualizou=true;
        canal[2].atualizou=true;
        canal[3].atualizou=true;
      
  }


 
}


void mouseClicked() {
  //-- verificar se é para abrir Serial --
  int r=com.mouseClicado();
  if (r==1) { // retornou 1 então abrir serial
    try {
      //port=new Serial(this,com.ports[com.indPort],int(com.speeds[com.indSpeed]));
      port=new Serial(this, com.ports[com.indPort], int(com.speeds[com.indSpeed]));
      port.bufferUntil(10); //configurado para pegar linhas inteiras
      com.conectado=true;
      com.erro=false;

  
    } 
    catch(Exception e) {
      println("erro abrindo Serial:", e);
      com.conectado=false;
      com.erro=true;
    }
  } else if (r==-1) { //retornou -1 então fechar serial
    port.stop();
    com.conectado=false;
    com.erro=false;
  }

  if (resetEixos.mouseClicado()){
    for (int k=0; k<4;k++){
     canal[k].p0=tela.y+3*Q*(k+1);//posição da tensão zero
    }
    resetEixos.clicado=false;
  }
  
  if (resetMedir.mouseClicado()){
     for (int k=0; k<4;k++){
        canal[k].telaClicou=false; 
     }
     resetMedir.clicado=false;
  }
  
 
  
  chXYZ.mouseClicado();
  
 
  
  for (int k=0; k<4; k++) {
    if (canal[k].mouseClicado()){ // se alterou o Chn para visível ou não visível
       if (com.conectado){                           // enviar comando para o Garagino não ler esse canal
         if (canal[k].chN.clicado){
            port.write("c"+str(k)+"o");
         } else {
            port.write("c"+str(k)+"x");
         }
       }
    }
  }

  for (int k=0; k<3;k++){
    if (demo[k].mouseClicado()) { // Acionar o DEMO e desmarcas os outros 2
      if (demo[k].clicado) {
        int total=0;
        for (int k2=0; k2<3;k2++){
          if (demo[k2].clicado) total++;          
        }
        if (total<=1) {
          tonSinal.salvar();
          fSinal.salvar();
          tSinal.salvar();
        }
        for (int j=0; j<k; j++) {
          demo[j].clicado=false;
        } 
        for (int j=2; j>k; j--) {
          demo[j].clicado=false;
        }
        tonSinal.alterar=altMove;
        fSinal.alterar=altMove;
        tSinal.alterar=altMove;
      } else {
        tonSinal.restaurar(); 
        tonSinal.alterar=altSolta;
        fSinal.restaurar();
        fSinal.alterar=altSolta;
        tSinal.restaurar();
        tSinal.alterar=altSolta;
      }
    }
  }
  
 
  
  // botões para medir tempo x tensão nos 4 canais (e botão de limpar x)
  /*
  for (int k=0;k<5;k++){
    if (medir[k].mouseClicado()){
       if (medir[k].clicado){
          for (int j=0; j<k;j++){
             medir[j].clicado=false; 
          }
          for (int j=3;j>k;j--){
            medir[j].clicado=false;
          }
       }
       if (k==4){ // limpar os retangulos
         for (int i=0; i<4; i++){
            canal[i].telaClicou=false; 
         }
       }
    }
  }
  */
  
  // botões para acionar o trigger nos canais
  /*
  for (int k=0;k<5;k++){
    if (trigger[k].mouseClicado()){
       if (trigger[k].clicado){
          for (int j=0; j<k;j++){
             trigger[j].clicado=false; 
          }
          for (int j=4;j>k;j--){
            trigger[j].clicado=false;
          }
          //enviar comando para o garagino
          if (com.conectado) {
            port.write("t"+trigger[k].tex);
          }      
       } else{
         if (com.conectado){
            port.write("tx"); 
         }
       }
    }
  }
  */
  
  verPontos.mouseClicado();
  calcFreq.mouseClicado();
  grafDif.mouseClicado();
  //ruido.mouseClicado();

  //se clicou em dt ou q então enviar comando para garagino e ajustar tela
  if (dt.mouseClicado()) { // se true alterou dt, então ajustarFt() (escala de t na tela)
    enviarDt();
    ajustarFt();
  }
  if (q.mouseClicado()) { // se true alterou q, então ajustarFt()
    enviarQ();
    ajustarFt();
  }

  if (RC.mouseClicado()) {
    if (com.conectado) {
      if (RC.clicado) {
        port.write("ro");
      } else {
        port.write("rx");
        RC.tex2="";
      }
    } else {
      RC.clicado=false;
    }
  }

  if (umaAmostra.mouseClicado()) { // receber apenas Uma Amostra
    variasAmostras.clicado=false;
    fluxoContinuo.clicado=false;
    if (com.conectado) {
      port.write("1"); 
    }
    umaAmostra.clicado=false;
    // verificar se tem algum trigger acionado para que ele fique esperando o disparo
    // vai ficar piscando para indicar que está aguardando o disparo.
    int k2=-1;
    for (int k=0; k<4;k++){
      if (canal[k].trigger.clicado) {
         k2=k;
         break; 
      }
    }
    println("k2=",k2);
    
    if (k2>=0 && k2<=3){
       pnlAmostra.piscar=true;
       canal[k2].trigger.piscar=true;
       esperandoTrigger=true;
    } else {
       pnlAmostra.piscar=false;
       esperandoTrigger=false;
     }
  }
  if (variasAmostras.mouseClicado()) {
    umaAmostra.clicado=false;
    fluxoContinuo.clicado=false;
    if (com.conectado) {
      if (variasAmostras.clicado) {
        port.write("vo");
      } else {
        port.write("vx");
      }
    } else {
      variasAmostras.clicado=false;
    }
  }
  if (fluxoContinuo.mouseClicado()) {
    umaAmostra.clicado=false;
    variasAmostras.clicado=false;
    if (com.conectado) {
      if (fluxoContinuo.clicado) {
        port.write("fo");
        
      } else {
        port.write("fx");
      }
    } else {
      fluxoContinuo.clicado=false;
    }
  }

  if (sinal.mouseClicado()){
     if (com.conectado){
        if (sinal.clicado){
           port.write("so"); 
        } else {
           port.write("sx");
        }
     }
  }
  
  if (fSinal.mouseClicado()){
    tSinal.setV(1/fSinal.v.v);
    enviarCmd("tSinal");
  }
  if (tSinal.mouseClicado()){
     fSinal.setV(1/tSinal.v.v);
     enviarCmd("tSinal");
  }
  if (tonSinal.mouseClicado()){
    enviarCmd("tonSinal");
  }
}

void mousePressed() {
  //d.mousePressionou(); 
  for (int k=0; k<4; k++) {
    canal[k].mousePressionou();
  }
  chXYZ.mousePressionou();
  dt.mousePressionou();
  q.mousePressionou();
  //ruido.mousePressionou();

  // só para aparecer o verde do pressionado
  umaAmostra.mousePressionou();
  variasAmostras.mousePressionou();
  fluxoContinuo.mousePressionou();

  fSinal.mousePressionou();
  tSinal.mousePressionou();
  tonSinal.mousePressionou();
  
  for (int k=0; k<3;k++){
     demo[k].mousePressionou(); 
  }
  resetEixos.mousePressionou();
  resetMedir.mousePressionou();

}

void mouseReleased() {
  // d.mouseSoltou();
  for (int k=0; k<4; k++) {
    canal[k].mouseSoltou();
  }
  chXYZ.mouseSoltou();

  for (int k=0; k<3;k++){
     demo[k].mouseSoltou(); 
  }
  resetEixos.mouseSoltou();
  resetMedir.mouseSoltou();
  // só para aparecer o verde do pressionado
  umaAmostra.mouseSoltou();
  variasAmostras.mouseSoltou();
  fluxoContinuo.mouseSoltou();


  //se soltar o mouse no dt ou q, então enviar os dados para o Garagino
  if (dt.mouseSoltou()) {
    enviarDt();
    ajustarFt();
  }
  if (q.mouseSoltou()) {
    enviarQ(); 
    // acertar as escalas ft de cada canal
    ajustarFt();
  }


  //ruido.mouseSoltou();

  if (fSinal.mouseSoltou()) {
    tSinal.setV(1/fSinal.v.v);
    enviarCmd("tSinal");
  }
  if (tSinal.mouseSoltou()) {
    fSinal.setV(1/tSinal.v.v);
    enviarCmd("tSinal");
  }
  if (tonSinal.mouseSoltou()){
    enviarCmd("tonSinal");
  }
  
  
  // controle do y do XYZ
  //if (XYZ.clicado){
  //    XYZyPegou=false; 
  //}


}

void mouseMoved() {
  //teste
  //  canal[0].cor=get(mouseX,mouseY);
  //    println("cor=",canal[0].cor);
  com.mouseMoveu();
  
  for (int k=0; k<4; k++) {
    canal[k].mouseMoveu();
  } 
  chXYZ.mouseMoveu();
  dt.mouseMoveu();
  q.mouseMoveu();
  //ruido.mouseMoveu();

  fSinal.mouseMoveu();
  tSinal.mouseMoveu();
  
  tonSinal.mouseMoveu();
}

void mouseDragged() {
  //d.mouseArrastou(); 
  for (int k=0; k<4; k++) {
    canal[k].mouseArrastou();
  }
  chXYZ.mouseArrastou();
  dt.mouseArrastou();
  q.mouseArrastou();
  //ruido.mouseArrastou();

  if (fSinal.alterar==altSolta){
    fSinal.mouseArrastou();
    tSinal.mouseArrastou();
  } else {
    if (fSinal.mouseArrastou()){
       tSinal.setV(1/fSinal.v.v); 
    }
    if (tSinal.mouseArrastou()){
      fSinal.setV(1/tSinal.v.v);
    }
  }
  
  
  tonSinal.mouseArrastou();

  // controle do y do XYZ
  //if (XYZ.clicado){
  //   if (XYZyPegou){
  //    XYZy=constrain(mouseY,tela.y,tela.y+10*Q)-mouseOffSet; 
  //   }
  //}
}


/* ==========================================
     Comando enviados para o Garagino 
   ========================================== */

//=== Ger.Sinal - Se alterou f/T/Ton - enviar comando para Garagino ==
void enviarCmd(String cmd){
  if (cmd.equals("tSinal")){
    if (com.conectado){
         port.write("p"+tSinal.v.printV());
         println("p"+tSinal.v.printV());
     }
  } else if (cmd.equals("tonSinal")){
    if (com.conectado){
         port.write("o"+tonSinal.v.printV()+"%");
         println("o"+tonSinal.v.printV()+"%");
      }
  }
}

//==Se alterou dt ou q enviar comando para Garagino e ajustar a escala da tela ==
void enviarDt() {
  if (com.conectado) {
    port.write("d"+dt.v.printV());
  } 
  // acertar as escalas ft de cada canal
  ajustarFt();
}
void enviarQ() {
  if (com.conectado) {
    port.write("q"+q.v.printV()+".");
  }
}

void ajustarFt() {
  float ftNew=dt.v.getV()*q.v.getV()/10.0;
  //println("ftNew=",ftNew," dt=",dt.v.getV()," q=",q.v.getV());
  for (int k=0; k<4; k++) {
    canal[k].ft.setV(ftNew);
  }
}

/*=====================================
      Entrada do Evento Porta Serial 
  =====================================*/
void serialEvent(Serial p) {
  //if (p.available()>0) {}
  String cmd="", val="";
  String tex=p.readStringUntil(10);
  //print(">>>> ",tex);
  if (tex.charAt(0)=='>') { //comando: >cmd=v1(tab)v2(tab)v3(tab)
    int i=tex.indexOf("=");
    if (i>=0) { // encontrou sinal "=" (igual)  obs: i=-1 => não encontrou o sinal '='
      cmd=tex.substring(1, i); // pegar o comando obs: substring(inclusive,exclusive)
      val=tex.substring(i+1); // pegar o valor
      //println("cmd=",cmd," val=",val);
      if (cmd.equals("f")) { // entra fluxo de dados - deslocar dados e armazenar no final
        String tex2[]=splitTokens(val); //val = "0(t)dtReal(t)ch0(t)ch1(t)ch2"
        //int vc[]=int(splitTokens(val));
        //deslocar os dados para baixo, para incluir o novo dado no final
        for (int j=0; j<4; j++) {
          for (int k=1; k<q.v.v; k++) {
            canal[j].v[k-1]=canal[j].v[k];
          }
        }
        canal[0].v[int(q.v.v-1)]=int(tex2[2]);
        canal[1].v[int(q.v.v-1)]=int(tex2[3]);
        canal[2].v[int(q.v.v-1)]=int(tex2[4]);
        canal[3].v[int(q.v.v-1)]=int(tex2[5]);
        dtReal.setV(float(tex2[1]));
        if (dtReal.v-dt.v.v>1.1*dt.v.v){ dtErro=true;} else {dtErro=false;}
        println("cmd=",cmd," val=",val," dtReal=",dtReal.printV());
      } else if (cmd.equals("v")) { // entrada de Varias Amostra
        int v[]=int(splitTokens(val));
        //println("v.length=",v.length);
        int kk=v[0]; // indice da matriz
        canal[0].buffer[v[0]]=v[1];
        canal[1].buffer[v[0]]=v[2];
        canal[2].buffer[v[0]]=v[3];
        canal[3].buffer[v[0]]=v[4];
      } else if (cmd.equals("q")) { // quantidade de variaveis
        //q.val=float(val);
      } else if (cmd.equals("dt")) { // tamanho do dt (ms)
        //dt.val=float(val);
      } else if (cmd.equals("tTotalReal")) { // tempo total da amostra
        //println("atualizou");
        tTotalReal.setV(float(val));
        //text(tTotalReal,pnlAmostra.x+2,pnlAmostra.y+pnlAmostra.h);
        println("cmd=",cmd," val=",val," tTotalReal=",tTotalReal.printV());
        canal[0].atualizou=true;  // terminou de entrar os dados então
        canal[1].atualizou=true;  //  carregar do buffer
        canal[2].atualizou=true;
        canal[3].atualizou=true;
        if (esperandoTrigger){
           esperandoTrigger=false;
           pnlAmostra.piscar=false;
           for (int k=0; k<4;k++){
             canal[k].trigger.piscar=false;
           }
           
        }
      } else if (cmd.equals("dtReal")){
        dtReal.setV(float(val));
        if (dtReal.n>dt.v.n+10){ dtErro=true;} else {dtErro=false;}
        //text(dtReal,pnlAmostra.x+2,pnlAmostra.y+pnlAmostra.h-12);
        println("cmd=",cmd," val=",val," dtReal=",dtReal.printV());
        
      } else if (cmd.equals("r") || cmd.equals("c") || cmd.equals("rc")) { // valor do resistor
        String tex2[]=splitTokens(val, "\t\r");
        //i=val.indexOf("\t");
        //for (int k=0; k<tex2.length; k++){
        //   print("tex2[",k,"]=",tex2[k]); 
        //}
        //println();
        if (cmd.equals("rc")) cmd="";
        RC.tex2=cmd.toUpperCase()+" "+tex2[1]+" ("+tex2[0]+")";
        
      } else if (cmd.charAt(0)=='?') {  // carregando as configurações do Garagino (ao conectar) 
        cmd=cmd.substring(2); // eliminar 2 caracteres iniciais "? comando"
        val=val.substring(0,val.length()-2); // eliminar 2 caracteres finais:  \n\r(13,10)(^M^J) (retorno de linha)        
        println("cmd=",cmd," val=",val);
        if (cmd.equals("q")){ // val=100
          q.v.v=float(val);
        } else if (cmd.equals("dt")){
          char unid=val.charAt(val.length()-2);
          val=val.substring(0,val.length()-2);
          println("unid=",unid," val=",val);
          if (unid=='u'){
            val=val+"e-6";            
          }else{
            val=val+"e-3";
          }
          println("val=",val);
          dt.setV(float(val));
          ajustarFt();
          
        }else if (cmd.equals("canalTrigger")){ // val= 0,1,2,x
           for (int k=0;k<4;k++){canal[k].trigger.clicado=false;}
           if (!val.equals("x")){
              canal[int(val)].trigger.clicado=true;   
           }
        } else if (cmd.equals("uma")){ // val= 0 ou 1
          //umaAmostra.clicado=boolean(int(val));
        }else if (cmd.equals("varias")){ // val= 0 ou 1
          variasAmostras.clicado=boolean(int(val));
        }else if (cmd.equals("fluxo")){ // val= 0 ou 1
          fluxoContinuo.clicado=boolean(int(val));
        }else if (cmd.equals("lerRC")){ // val= 0 ou 1
          RC.clicado=boolean(int(val));
        }else if (cmd.equals("pwmOn")){ // val=0 ou 1 (false/true) 
          sinal.clicado=boolean(int(val));
          //println("sinal.clicado=",sinal.clicado," val=",val," boolean(val)=",boolean(val));
          //for (int k=0; k<val.length();k++){
          //   println(k," - ",val.charAt(k)," - ",byte(val.charAt(k)));
          //}
          //println("int(val)=",int(val)," int(''0'')",int("0")," int(''1'')",int(1));
          //println("b(''0'')=",boolean("0")," b(''1'')=",boolean("1")," b('0')=",boolean('0')," b('1')=",boolean('1'));
        }else if (cmd.equals("pwmP")){ // cmd="pwmP", val=" 100000us"
          val=val.substring(0,val.length()-2)+"e-6"; // remover "us" e colocar "e-6" (microsegundos)
          tSinal.setV(float(val));
          fSinal.setV(1/tSinal.v.v);
          //println("pwmP=",float(val));
        }else if (cmd.equals("pwmPon")){  // cmd="pwmPon", val="25%"
          val=val.substring(0,val.length()-1);
          tonSinal.setV(float(val));
          println("pwmPon=",float(val));
        }
      }
    }
    //println("cmd=",cmd);
    //println("val=",val);
  }
}
