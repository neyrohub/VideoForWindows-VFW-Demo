unit UWriteThread;

interface

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TWriteThread.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ TWriteThread }

uses
  SysUtils, Windows, Classes, Graphics;

type
  TWriteThread = class(TThread)
  private
    { Private declarations }
    Count: integer;
  protected
    procedure DoWork;
    procedure Execute; override;
  public
    procedure OnCanvasPaint(Sender: TObject);
    constructor Create(Suspended: boolean);
  end;

implementation

uses uMain;

procedure TWriteThread.OnCanvasPaint(Sender: TObject);
begin
//inc(Count);
end;

constructor TWriteThread.Create(Suspended: boolean);
begin
  Count := 0;
  inherited Create(Suspended);
//  VideoBTM.Canvas.OnChange := self.OnCanvasPaint;
end;

procedure TWriteThread.Execute;
var FrameInterval: integer;
begin
FrameInterval := GetTickCount() + round(1000/CurrentFrameRate);//пытаемся синхронизировать межкадровый интервал
{Пока процесс не прервали, выполняем DoWork}
  while not Terminated do
    begin

   //первый вариант
//    try
//      CriticalSection.Enter;
//      CriThreadFight := 'Trolo-lo-lo!';
//    finally
//      CriticalSection.Leave;
//    end;
    if FrameInterval <= (GetTickCount()) then
      begin
      Synchronize(DoWork);
      FrameInterval := GetTickCount() + round(1000/CurrentFrameRate);//пытаемся синхронизировать межкадровый интервал
      end;
      sleep(1);
    end;

end;

procedure TWriteThread.DoWork;
begin
//первый вариант
  try
    CriticalSection.Enter;
    if FVideoCaptureFilter = NIL then EXIT;
    if FSampleGrabber = NIL then EXIT;
    if VideoForm.PaintBox1.Canvas.LockCount = 0 then
      begin
      VideoForm.PaintBox1.Canvas.Lock;
      if FAILED(VideoForm.CaptureBitmap) then
        Begin
        VideoForm.PaintBox1.Canvas.TextOut(0, 30, 'Внимание! Произошла ошибка при получении изображения');// +
        VideoForm.PaintBox1.Canvas.TextOut(0, 45, 'Error: ' + VideoForm.LastErrorMess);// +
        //Exit;
        End
      else
        begin
        VideoForm.PaintBox1.Canvas.TextOut(0, 0, 'Нет кадра для отрисовки (холостой ход) = ' +
                     inttostr(Count));
        inc(Count);
        end;
      VideoForm.PaintBox1.Canvas.Unlock;
      end;
  finally
    CriticalSection.Leave;
  end;
end;

end.
