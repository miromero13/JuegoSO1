unit uFrmMain;

interface

uses
  uCola,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus;

type
  TForm1 = class(TForm)
    MainMenu: TMainMenu;
    Juego1: TMenuItem;
    Jugar: TMenuItem;
    N1: TMenuItem;
    Salir: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure JugarClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SalirClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    User: PCB;
    // Para almacenar al personaje del usuario.  Este PCB no se encolar�, y por tanto no lo manipular� el PlanificadorRR.
    Q: Cola; // Cola del Planificador RR.
    Estado: Integer; // 0=No pasa nada, 1=Muri� el User, 2=Muri� la Nave
    canon: PCB;
    BalaColor: Integer;

    procedure InitJuego();
    procedure CicloJuego;
    procedure Planificador();

    procedure MoverNave(PRUN: PCB);
    procedure MoverBalaN(PRUN: PCB);
    procedure MoverBalaU(PRUN: PCB);

    procedure cls;
    procedure Dibujar(P: PCB);
    procedure Borrar(P: PCB);
    procedure Rectangulo(x, y, Ancho, Alto, Color: Integer);
    function MaxX: Integer;
    function MaxY: Integer;
    function Colision(P1, P2: PCB): Boolean;
    procedure DispararBalaEnemiga(Nave: PCB);
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);

begin
  Q := Cola.Create; // Construir (new) la cola del PlanificadorRR.
  BalaColor := clRed;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  Estado := -1; // Salir del while (Estado=0) del proc. CicloJuego()
  CanClose := true;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  X2Canon: Integer;
  P: PCB;

begin // Evento: Se presion� una tecla.
  case Key of
    VK_LEFT:
      begin
        Borrar(canon);
        canon.x := canon.x - 5;
        if canon.x < 0 then
          canon.x := 0; // Clamp X a 0

        Dibujar(canon);
      end;

    VK_RIGHT:
      begin
        Borrar(canon);
        canon.x := canon.x + 5;
        X2Canon := canon.x + canon.Ancho - 1;

        if X2Canon > MaxX then
          canon.x := MaxX - canon.Ancho + 1;

        Dibujar(canon);
      end;

    VK_SPACE:
      begin
        canon.Color := BalaColor;
        // Aseg�rate de que el ca��n tenga el color correcto
        Dibujar(canon); // Redibuja el ca��n

        // Crear la bala con el color actual
        P.Tipo := BALAU;
        P.Alto := 15;
        P.Ancho := 5;
        P.Color := BalaColor; // Color actual de la bala
        P.Retardo := 25;
        P.y := canon.y - P.Alto;
        P.x := (canon.Ancho - P.Ancho) div 2 + canon.x;

        P.Hora := GetTickCount();
        // Asigna la hora de disparo para controlar el tiempo
        Dibujar(P); // Dibuja la bala en la pantalla
        Q.Meter(P); // A�ade la bala a la cola para ser procesada

        // Cambiar al siguiente color c�clicamente
        if BalaColor = clRed then
          BalaColor := clYellow
        else if BalaColor = clYellow then
          BalaColor := clBlue
        else
          BalaColor := clRed;
      end;
  end;
end;

procedure TForm1.JugarClick(Sender: TObject);
begin
  InitJuego();
end;

procedure TForm1.SalirClick(Sender: TObject);
begin
  close(); // Generar el evento FormCloseQuery
end;

procedure TForm1.InitJuego;
var
  P: PCB;
  i, j: Integer;
  DivisionAncho: Integer;
  OffsetX: Integer;
begin
  cls(); // Limpiar pantalla

  // Dibujar las paredes divisorias
  Rectangulo(MaxX div 3, 0, 5, MaxY, clGray); // Primera pared
  Rectangulo((2 * MaxX) div 3, 0, 5, MaxY, clGray); // Segunda pared

  // Configurar el ca��n
  canon.Ancho := 30;
  canon.Alto := 30;
  canon.y := MaxY - canon.Alto;
  canon.x := (MaxX - canon.Ancho) div 2;
  canon.Color := clGreen;
  Dibujar(canon);

  // Inicializar cola
  Q.Init();

  DivisionAncho := MaxX div 3;

  for j := 0 to 2 do // Iterar por las tres divisiones
  begin
    OffsetX := j * DivisionAncho;
    // Calcular el desplazamiento horizontal para cada divisi�n

    for i := 0 to 2 do // Crear tres naves por divisi�n
    begin
      P.Tipo := Nave;
      P.Ancho := 30;
      P.Alto := 30;

      if i = 1 then
        P.y := 50 // Nave del medio en la parte superior
      else
        P.y := 80; // Naves extremas un poco m�s abajo

      P.x := OffsetX + 10 + i * 40; // Posicionarlas dentro de la divisi�n

      // Asignar un color diferente a cada nave
      case i of
        0:
          P.Color := clRed;
        1:
          P.Color := clYellow;
        2:
          P.Color := clBlue;
      end;

      // Configuraci�n adicional
      P.Retardo := 100;
      P.Hora := GetTickCount();
      P.Dir := 1; // Inicializar la direcci�n de movimiento hacia la derecha
      Dibujar(P);
      Q.Meter(P);
    end;
  end;

  CicloJuego();
end;

procedure TForm1.CicloJuego;
begin
  Estado := 0;

  while Estado = 0 do
  begin
    Planificador();
    Application.ProcessMessages(); // Para procesar los eventos del user.
  end;

end;

procedure TForm1.DispararBalaEnemiga(Nave: PCB);
var
  Bala: PCB;
begin
  Bala.Tipo := BALAN;
  Bala.Ancho := 5;
  Bala.Alto := 15;
  Bala.Color := Nave.Color;
  Bala.Retardo := 30; // Retardo de movimiento
  Bala.y := Nave.y + Nave.Alto; // Posici�n inicial de la bala debajo de la nave
  Bala.x := Nave.x + (Nave.Ancho - Bala.Ancho) div 2;
  Bala.Hora := GetTickCount();
  Dibujar(Bala);
  Q.Meter(Bala);
end;

procedure TForm1.Planificador;
var
  PRUN: PCB;
begin
  PRUN := Q.Sacar();

  if (PRUN.Hora + PRUN.Retardo > GetTickCount()) then
    Q.Meter(PRUN)
  else
  begin
    case PRUN.Tipo of
      Nave:
        begin
          MoverNave(PRUN);
          if Random(100) < 10 then // Probabilidad de disparar (10%)
            DispararBalaEnemiga(PRUN);
        end;
      BALAN:
        MoverBalaN(PRUN);
      BALAU:
        MoverBalaU(PRUN);
    end;
  end;
end;

procedure TForm1.MoverNave(PRUN: PCB);
var
  DivisionAncho, DivisionInicio, DivisionFin: Integer;
begin
  DivisionAncho := MaxX div 3; // Calcular el ancho de cada divisi�n

  // Calcular los l�mites de la divisi�n donde est� la nave
  DivisionInicio := (PRUN.x div DivisionAncho) * DivisionAncho;
  DivisionFin := DivisionInicio + DivisionAncho;

  Borrar(PRUN); // Borrar la nave

  // Cambiar la direcci�n si alcanza los bordes de la divisi�n
  if (PRUN.x <= DivisionInicio) then
    PRUN.Dir := 1 // Cambiar direcci�n a la derecha
  else if (PRUN.x + PRUN.Ancho >= DivisionFin) then
    PRUN.Dir := -1; // Cambiar direcci�n a la izquierda

  // Mover la nave en la direcci�n actual
  PRUN.x := PRUN.x + (5 * PRUN.Dir);

  PRUN.Hora := GetTickCount();
  Dibujar(PRUN); // Redibujar la nave
  Q.Meter(PRUN); // Volver a meter la nave en la cola
end;

procedure TForm1.MoverBalaN(PRUN: PCB);
begin
  Borrar(PRUN);
  PRUN.y := PRUN.y + 5;

  // Comprobar si la bala toca el ca��n
  if Colision(PRUN, canon) then
  begin
    Estado := 1; // El jugador ha perdido
    ShowMessage('�Has perdido!'); // Mostrar mensaje de derrota
    // Exit;  // Salir de la funci�n si hay colisi�n
    close();
  end;

  // Si la bala no toca el ca��n, contin�a movi�ndose
  if (PRUN.y < MaxY) then
  begin
    PRUN.Hora := GetTickCount;
    Dibujar(PRUN);
    Q.Meter(PRUN);
  end;
end;

procedure TForm1.MoverBalaU(PRUN: PCB);
var
  Temp: PCB;
  i, N: Integer;
  ColisionDetectada: Boolean;
begin
  Borrar(PRUN);
  PRUN.y := PRUN.y - 5;  // Mover la bala hacia arriba
  // Dibujar las paredes divisorias
  Rectangulo(MaxX div 3, 0, 5, MaxY, clGray); // Primera pared
  Rectangulo((2 * MaxX) div 3, 0, 5, MaxY, clGray); // Segunda pared

  ColisionDetectada := False;
  N := Q.Length();
  for i := 1 to N do
  begin
    Temp := Q.Sacar();

    if (Temp.Tipo = NAVE) and Colision(PRUN, Temp) then
    begin
      ColisionDetectada := True;
      Temp.Color := PRUN.Color;  // Cambiar el color de la nave
      Dibujar(Temp);  // Redibujar la nave con el nuevo color
    end;

    Q.Meter(Temp);  // Volver a poner la nave en la cola
  end;

  if not ColisionDetectada and (PRUN.y > 0) then
  begin
    PRUN.Hora := GetTickCount();
    Dibujar(PRUN);  // Redibujar la bala
    Q.Meter(PRUN);  // Volver a poner la bala en la cola
  end
  else
  begin
    Borrar(PRUN);  // Borrar la bala si colision�
  end;
end;


// ------------ Funciones para Manipular los "Gr�ficos" -------------------------
procedure TForm1.cls;
begin // Borra el canvas (lienzo) del formulario
  Rectangulo(0, 0, MaxX() + 1, MaxY() + 1, Color);
end;

procedure TForm1.Dibujar(P: PCB);
begin // Dibuja al PCB P como un rectangulo en la pantalla.
  Rectangulo(P.x, P.y, P.Ancho, P.Alto, P.Color);
end;

procedure TForm1.Borrar(P: PCB);
begin // Dibuja al PCB P como un rectangulo en la pantalla, del mismo color del Form.
  Rectangulo(P.x, P.y, P.Ancho, P.Alto, SELF.Color);
end;

procedure TForm1.Rectangulo(x, y, Ancho, Alto, Color: Integer);
begin // Dibuja un rectangulo con esquina superior Izq en (x,y).
  Canvas.Pen.Color := Color;
  Canvas.Brush.Color := Color;
  Canvas.Rectangle(x, y, x + Ancho - 1, y + Alto - 1);
end;

function TForm1.MaxX: Integer;
begin
  RESULT := ClientWidth - 1;
end;

function TForm1.MaxY: Integer;
begin
  RESULT := ClientHeight - 1;
end;

function TForm1.Colision(P1, P2: PCB): Boolean;
begin
  RESULT := (P1.x < P2.x + P2.Ancho) and (P1.x + P1.Ancho > P2.x) and
    (P1.y < P2.y + P2.Alto) and (P1.y + P1.Alto > P2.y);
end;

END.
