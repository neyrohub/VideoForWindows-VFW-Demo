unit uAverageSpeedCounter;
//Этот юнит считает среднюю скорость потока

interface

uses
  Windows, SysUtils, classes;

type
  TMomentumSpeed = packed record
  MomentumSpeed: cardinal;
  MomentumTick: cardinal;
end;
pMomentumSpeed = ^TMomentumSpeed;

type
  TMomentumFps = packed record
  MomentumFps: cardinal;
  MomentumTick: cardinal;
end;
pMomentumFps = ^TMomentumFps;

type
  TAverageSpeedCounter = class(TPersistent)
  protected
  private
    { Private declarations }
    FAverageSpeed: cardinal;
    FTotalTraffic: cardinal;
    FTotalSpeedSum: cardinal;
    FTotalFpsSum: cardinal;
    FTicPeriodSpeed: cardinal;
    FTicPeriodFps: cardinal;
    MomentsList: TList;
    FpsList: TList;
    function GetAverageSpeed: cardinal;
    function GetAverageFps: cardinal;
  public
    { Public declarations }
    property TotalTraffic: cardinal read FTotalTraffic;
    property AverageSpeed: cardinal read GetAverageSpeed;
    property AverageFPS: cardinal read GetAverageFps;
    procedure AddMomentalSpeed(Value: cardinal);
    procedure AddMomentalFps(Value: cardinal);
    constructor Create(TicPeriodSpeed: cardinal; TicPeriodFps: cardinal);
    destructor Destroy;override;
  end;

implementation

constructor TAverageSpeedCounter.Create(TicPeriodSpeed: cardinal; TicPeriodFps: cardinal);
begin
inherited Create();
MomentsList := TList.Create;
FpsList := TList.Create;
FTotalTraffic := 0;
FTotalSpeedSum := 0;
FAverageSpeed := 0;
FTotalFpsSum := 0;
FTicPeriodSpeed := TicPeriodSpeed;
FTicPeriodFps := TicPeriodFps;
end;


destructor TAverageSpeedCounter.Destroy;
begin
while MomentsList.Count > 0 do
  begin
  FreeMem(MomentsList.First);
  MomentsList.Delete(0);
  end;
FreeAndNil(MomentsList);

while FpsList.Count > 0 do
  begin
  FreeMem(FpsList.First);
  FpsList.Delete(0);
  end;
FreeAndNil(FpsList);
inherited Destroy;
end;

function TAverageSpeedCounter.GetAverageSpeed: cardinal;
var pMoment: pMomentumSpeed;
begin
//Нам нужно сложить все отчеты за указанный период FTicPeriod
//и поделить их на период FTicPeriod
//сначала находим самый первый отчет. Смотрим какой у него тик?
//сравниваем с текущим
result := 0;
while (MomentsList.Count > 0) and
 ((GetTickCount - FTicPeriodSpeed) > pMomentumSpeed(MomentsList.First).MomentumTick) do
  begin
  //т.е. данный отчет уже устарел более чем на период
  //например, нас интересует период 1000мс, этот отчет устарел на 1400мс
  //он нам не нужен!
  FTotalSpeedSum := FTotalSpeedSum - pMomentumSpeed(MomentsList.First).MomentumSpeed;
  FreeMem(MomentsList.First);
  MomentsList.Delete(0);
  end;
//result := round(FTotalSpeedSum/(FTicPeriod/1000));
if (MomentsList.Count <= 0) then exit;
result := round(FTotalSpeedSum/MomentsList.Count);
end;

procedure TAverageSpeedCounter.AddMomentalSpeed(Value: cardinal);
var pMoment: pMomentumSpeed;
begin
GetMem(pMoment, SizeOf(TMomentumSpeed));
pMoment.MomentumTick := GetTickCount();
pMoment.MomentumSpeed := Value;
FTotalTraffic := FTotalTraffic + Value;
MomentsList.Add(pMoment);
FTotalSpeedSum := FTotalSpeedSum + Value;
GetAverageSpeed();
end;

function TAverageSpeedCounter.GetAverageFps: cardinal;
var pMoment: pMomentumFps;
begin
result := 0;
while (FpsList.Count > 0) and
 ((GetTickCount - FTicPeriodFps) > pMomentumSpeed(FpsList.First).MomentumTick) do
  begin
  //т.е. данный отчет уже устарел более чем на период
  //например, нас интересует период 1000мс, этот отчет устарел на 1400мс
  //он нам не нужен!
  FTotalFpsSum := FTotalFpsSum - pMomentumFps(FpsList.First).MomentumFps;
  FreeMem(FpsList.First);
  FpsList.Delete(0);
  end;
//result := round(FTotalSpeedSum/(FTicPeriod/1000));
if (FpsList.Count <= 0) then exit;
result := FpsList.Count;
end;

procedure TAverageSpeedCounter.AddMomentalFps(Value: cardinal);
var pMoment: pMomentumFps;
begin
GetMem(pMoment, SizeOf(TMomentumFps));
pMoment.MomentumTick := GetTickCount();
pMoment.MomentumFps:= Value;
FpsList.Add(pMoment);
FTotalFpsSum := FTotalFpsSum + 1;
GetAverageFps();
end;

end.
