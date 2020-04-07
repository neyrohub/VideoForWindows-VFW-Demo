unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Menus,
  ExtCtrls, ActiveX, SyncObjs,
  DSUtil, DSPack,  DirectShow9,
  VFW, uVideoCoDec,
  UWriteThread, uAverageSpeedCounter;

type
  TVideoForm = class(TForm)
    FilterGraph: TFilterGraph;
    MainMenu1: TMainMenu;
    Filter: TFilter;
    SampleGrabber: TSampleGrabber;
    ListBox1: TListBox;
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    cbxCodecs: TComboBox;
    Memo1: TMemo;
    PinInterfaces: TListBox;
    Button3: TButton;
    PaintBox1: TPaintBox;
    PaintBox2: TPaintBox;
//    procedure ShowPins;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    function  Init: HResult;
    function CreateGraph: HResult;
    function CaptureBitmap: HResult;
    Function  SetVideoParams(CB_B2: ICaptureGraphBuilder2; Category: TGUID;
              fSource: IBaseFilter): HResult;
    procedure Button1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    function GetCurrentVideoFormat(): TBitmapInfo;//Header;
    procedure DDDraw(Canvas: TCanvas; dTop, dLeft, dHeight, dWidth: Integer;
                                             Bitmap: TBitmap);
    procedure Button3Click(Sender: TObject);
  private
    { Dйclarations privйes }
  public
    { Dйclarations publiques }
    LastErrorMess: string;
  end;

var
  VideoForm: TVideoForm;
  WriteThread: TWriteThread;
  SysDev: TSysDevEnum;
  CriticalSection: TCriticalSection;
  TempBitmap, Bitmap, VideoBTM: TBitmap;
  rmin, rmax, gmin, gmax, bmin, bmax: byte;
//  FileName: string;
  RecMode: boolean = False;
  DeviceName: OleVariant;
  PropertyName: IPropertyBag;
  pDevEnum: ICreateDEvEnum;
  pEnum: IEnumMoniker;
  pMoniker: IMoniker;

  VideoCoDec1        : TVideoCoDec;
  AverageSpeedCounter : TAverageSpeedCounter;
  CoderCompressedVideoFormat: TBitmapInfo;//Header;
  CoderBMPVideoFormat       : TBitmapInfo;//Header;
  DecoderCompressedVideoFormat: TBitmapInfo;//Header;
  pDecoderCompressedVideoFormat: pBitmapInfo;//Header;
  DecoderBMPVideoFormat       : TBitmapInfo;//Header;
  CurrentFrameRate   : Integer;

  MArray1: array of IMoniker; //Это список моникеров, из которго
//мы потом будем получать необходмый моникер

//интерфейсы
    FGraphBuilder:        IGraphBuilder;
    FCaptureGraphBuilder: ICaptureGraphBuilder2;
    FMux:                 IBaseFilter;
    FSink:                IFileSinkFilter;
    FMediaControl:        IMediaControl;
    FVideoWindow:         IVideoWindow;
    FVideoCaptureFilter:  IBaseFilter;
    FAudioCaptureFilter:  IBaseFilter;
//область вывода изображения
    FVideoRect:           TRect;

    FBaseFilter:          IBaseFilter;
    FSampleGrabber:       ISampleGrabber;
//    MediaType:            AM_MEDIA_TYPE;


implementation

{$R *.dfm}
{
procedure TVideoForm.ShowPins( );
var
  i: integer;
  unk: IUnknown;
  EnumMT : TEnumMediaType;
begin
  PinInterfaces.Clear;
  if lbPins.ItemIndex <> -1 then
  try
    with PinList.Items[lbPins.ItemIndex] do
      for i := 0 to length(DSItfs)-1 do
        if Succeeded(QueryInterface(DSItfs[i].itf, unk)) then
          PinInterfaces.Items.Add(DSItfs[i].name);
  finally
    unk := nil;
  end;

  MediaTypes.Clear;
  if lbPins.ItemIndex <> -1 then
  begin
    EnumMT:= TEnumMediaType.Create(PinList.Items[lbPins.ItemIndex]);
    try
      if EnumMT.Count > 0 then
        for i := 0 to EnumMT.Count - 1 do
          MediaTypes.Items.Add(EnumMt.MediaDescription[i]);
    finally
      EnumMT.Free;
    end;
  end;

end;
}
function TVideoForm.GetCurrentVideoFormat(): TBitmapInfo;//Header;
var
  Res: HResult;
//  numPinFound: Cardinal;
  MediaType: AM_MEDIA_TYPE;
begin
Res := FSampleGrabber.GetConnectedMediaType(MediaType);
if not FAILED(Res) then
  begin
   if IsEqualGUID(MediaType.formattype, FORMAT_VideoInfo) then
     begin
     //MediaType.majortype
     if (MediaType.cbFormat = SizeOf(TVideoInfoHeader)) then
       begin
       CoderBMPVideoFormat.bmiHeader := PVideoInfoHeader(MediaType.pbFormat)^.bmiHeader;
//       BMPVideoFormat.bmiColors := PVideoInfoHeader(MediaType.pbFormat)^.bmiColors;
       memo1.Lines.Add('Размер кадра: (' +
                       inttostr(CoderBMPVideoFormat.bmiHeader.biWidth) + 'x' +
                       inttostr(CoderBMPVideoFormat.bmiHeader.biHeight) + ' цвет ' +
                       inttostr(CoderBMPVideoFormat.bmiHeader.biBitCount) + ' бит' +
                       ')');
       memo1.Lines.Add('MediaType.cbFormat = ' +
                        inttostr(MediaType.cbFormat));
       memo1.Lines.Add('Кадров в секунду ' + inttostr(10000000 div PVideoInfoHeader(MediaType.pbFormat)^.AvgTimePerFrame));
       CurrentFrameRate := 10000000 div PVideoInfoHeader(MediaType.pbFormat)^.AvgTimePerFrame;
       if MediaType.subtype.D1 = MEDIASUBTYPE_YUY2.D1 then
         begin
         memo1.Lines.Add('MEDIASUBTYPE_YUY2');
         CoderBMPVideoFormat.bmiHeader.biCompression := MEDIASUBTYPE_YUY2.D1;
         end;
       if MediaType.subtype.D1 = MEDIASUBTYPE_RGB24.D1 then
         begin
         memo1.Lines.Add('MEDIASUBTYPE_RGB24');
         CoderBMPVideoFormat.bmiHeader.biCompression := 0;//MEDIASUBTYPE_RGB24.D1;
         end;
       result := CoderBMPVideoFormat;
       end;
     end
   else
     begin
     memo1.Lines.Add('К устройству подключен фильтр <> FORMAT_VideoInfo');
     end;
  end;
end;


procedure TVideoForm.FormCreate(Sender: TObject);
begin
LastErrorMess := '';
memo1.Lines.Clear;
VideoBTM := TBitmap.Create;
VideoBTM.Width := 640;
VideoBTM.Height := 480;

CriticalSection := TCriticalSection.Create;

//загружаем настройки из ini файла
//LoadIniFiles;
CoInitialize(nil);// инициализировать OLE COM
//вызываем процедуру поиска и инициализации устройств захвата видео и звука
if FAILED(VideoForm.Init) then
  Begin
  ShowMessage('Внимание! Произошла ошибка при инициализации');
  Exit;
  End;

//проверяем найденный список устройств
if Listbox1.Count > 0 then
  Begin
  //если необходимые для работы устройства найдены,
  //то вызываем процедуру построения графа фильтров
  if FAILED(CreateGraph) then
    Begin
    ShowMessage('Внимание! Произошла ошибка при построении графа фильтров');
    Exit;
    End;
  end
else
  Begin
  ShowMessage('Внимание! Камера не обнаружена.');
  //Application.Terminate;
  End;

VideoCoDec1 := TVideoCoDec.Create;
VideoCoDec1.EnumCodecs(cbxCodecs.Items);
if cbxCodecs.Items.Count > 0 then
  begin
  cbxCodecs.ItemIndex := 0;
  cbxCodecs.Text := cbxCodecs.Items[0];
  end;

AverageSpeedCounter := TAverageSpeedCounter.Create(1000, 1000);

WriteThread := TWriteThread.Create(true);
//WriteThread.Priority := tpLowest;//tpNormal;//Highest;//tpHighest;
//WriteThread.Priority := tpNormal;//Highest;//tpHighest;
WriteThread.Priority := tpHigher;
//WriteThread.Priority := tpHighest;
//WriteThread.Priority := tpTimeCritical;
end;

procedure TVideoForm.Button3Click(Sender: TObject);
begin
   VideoCoDec1.ChooseCodec;
end;

procedure TVideoForm.FormDestroy(Sender: TObject);
begin
if pDecoderCompressedVideoFormat <> nil then freeMem(pDecoderCompressedVideoFormat);
if WriteThread <> nil then WriteThread.Terminate;
if VideoCoDec1 <> nil then
  begin
  VideoCoDec1.CloseCompressor;
  VideoCoDec1.CloseDecompressor;
  VideoCoDec1.Free;
  AverageSpeedCounter.Free;
  end;
VideoBTM.Free;
CriticalSection.Free;
if SysDev <> nil then SysDev.Free;
FilterGraph.ClearGraph;
end;

procedure TVideoForm.Button1Click(Sender: TObject);
//Вызов страницы свойств Web-камеры
var
  StreamConfig: IAMStreamConfig;
  PropertyPages: ISpecifyPropertyPages;
  Pages: CAUUID;
Begin
//если запись уже идет - выходим
If RecMode then Exit;
  // Если отсутствует интерфейс работы с видео, то завершаем работу
  if FVideoCaptureFilter = NIL then EXIT;
  // Останавливаем работу графа
  FMediaControl.Stop;
  try
    // Ищем интерфейс управления форматом данных выходного потока
    // Если интерфейс найден, то ...
    if SUCCEEDED(FCaptureGraphBuilder.FindInterface(@PIN_CATEGORY_CAPTURE,
      @MEDIATYPE_Video, FVideoCaptureFilter, IID_IAMStreamConfig, StreamConfig)) then
    begin
      // ... пытаемся найти интерфейс управления страницами свойств ...
      // ... и, если он найден, то ...
      if SUCCEEDED(StreamConfig.QueryInterface(ISpecifyPropertyPages, PropertyPages)) then
      begin
        // ... получаем массив страниц свойств
        PropertyPages.GetPages(Pages);
        PropertyPages := NIL;

        // Отображаем страницу свойств в виде модального диалога
        OleCreatePropertyFrame(
           Handle,
           0,
           0,
           PWideChar(ListBox1.Items.Strings[listbox1.ItemIndex]),
           1,
           @StreamConfig,
           Pages.cElems,
           Pages.pElems,
           0,
           0,
           NIL
        );

        // Освобождаем память
        StreamConfig := NIL;
        CoTaskMemFree(Pages.pElems);
      end;
    end;

  finally
    // Восстанавливаем работу графа
    FMediaControl.Run;
  end;
end;

function TVideoForm.Init: HResult;
begin
//Создаем объект для перечисления устройств
Result := CoCreateInstance(CLSID_SystemDeviceEnum, NIL, CLSCTX_INPROC_SERVER,
IID_ICreateDevEnum, pDevEnum);
if Result <> S_OK then EXIT;

//Перечислитель устройств Video
Result := pDevEnum.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, pEnum, 0);
if Result <> S_OK then EXIT;
//Обнуляем массив в списке моникеров
setlength(MArray1, 0);
//Пускаем массив по списку устройств
while (S_OK=pEnum.Next(1,pMoniker,Nil)) do
  begin
  setlength(MArray1, length(MArray1) + 1); //Увеличиваем массив на единицу
  MArray1[length(MArray1) - 1] := pMoniker; //Запоминаем моникер в масиве
  Result := pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName); //Линкуем моникер устройства к формату хранения IPropertyBag
  if FAILED(Result) then Continue;
  Result := PropertyName.Read('FriendlyName', DeviceName, NIL); //Получаем имя устройства
  if FAILED(Result) then Continue;
//Добавляем имя устройства в списки
  Listbox1.Items.Add(DeviceName);
  end;

//Первоначальный выбор устройств для захвата видео
//Выбираем из спика камеру
if ListBox1.Count=0 then
   begin
      ShowMessage('Камера не обнаружена');
      Result:=E_FAIL;;
      Exit;
   end;
Listbox1.ItemIndex:=0;
//если все ОК
Result:=S_OK;
end;

function TVideoForm.CreateGraph: HResult;
var
  pConfigMux: IConfigAviMux;
  MediaType:            AM_MEDIA_TYPE;
begin
//Чистим граф
  FVideoCaptureFilter  := NIL;
  FVideoWindow         := NIL;
  FMediaControl        := NIL;
  FSampleGrabber       := NIL;
  FBaseFilter          := NIL;
  FCaptureGraphBuilder := NIL;
  FGraphBuilder        := NIL;

//Создаем объект для графа фильтров
Result:=CoCreateInstance(CLSID_FilterGraph, NIL, CLSCTX_INPROC_SERVER, IID_IGraphBuilder, FGraphBuilder);
if FAILED(Result) then EXIT;
// Создаем объект для граббинга
Result := CoCreateInstance(CLSID_SampleGrabber, NIL, CLSCTX_INPROC_SERVER, IID_IBaseFilter, FBaseFilter);
if FAILED(Result) then EXIT;
//Создаем объект для графа захвата
Result := CoCreateInstance(CLSID_CaptureGraphBuilder2, NIL, CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, FCaptureGraphBuilder);
if FAILED(Result) then EXIT;

// Добавляем фильтр в граф
Result := FGraphBuilder.AddFilter(FBaseFilter, 'GRABBER');
if FAILED(Result) then EXIT;
// Получаем интерфейс фильтра перехвата
Result := FBaseFilter.QueryInterface(IID_ISampleGrabber, FSampleGrabber);
if FAILED(Result) then EXIT;

  if FSampleGrabber <> NIL then
  begin
    //обнуляем память
    ZeroMemory(@MediaType, sizeof(AM_MEDIA_TYPE));
    // Устанавливаем формат данных для фильтра перехвата
    with MediaType do
      begin
      majortype  := MEDIATYPE_Video;
      subtype    := MEDIASUBTYPE_RGB24;
//      subtype    := MEDIASUBTYPE_YUY2;
      formattype := FORMAT_VideoInfo;
      end;
    Result := FSampleGrabber.SetMediaType(MediaType);
    if FAILED(Result) then
      begin
      memo1.Lines.Add('SetMediaType(MediaType) failed');
      EXIT;
      end;
    memo1.Lines.Add('MediaType.majortype = ' + GetGUIDString(MediaType.majortype));
    memo1.Lines.Add('MediaType.subtype = ' + GetGUIDString(MediaType.subtype));
    memo1.Lines.Add('MediaType.formattype = ' + GetGUIDString(MediaType.formattype));
    memo1.Lines.Add(GetMediaTypeDescription(@MediaType));

    // Данные будут записаны в буфер в том виде, в котором они
    // проходят через фильтр
    FSampleGrabber.SetBufferSamples(TRUE);

    // Граф не будет остановлен для получения кадра
    FSampleGrabber.SetOneShot(FALSE);
  end;

//Задаем граф фильтров
Result := FCaptureGraphBuilder.SetFiltergraph(FGraphBuilder);
if FAILED(Result) then EXIT;

//выбор устройств ListBox - ов
if Listbox1.ItemIndex >= 0 then
  begin
  //получаем устройство для захвата видео из списка моникеров
  MArray1[Listbox1.ItemIndex].BindToObject(NIL, NIL, IID_IBaseFilter, FVideoCaptureFilter);
  //добавляем устройство в граф фильтров
  FGraphBuilder.AddFilter(FVideoCaptureFilter, 'VideoCaptureFilter'); //Получаем фильтр графа захвата
  end;

//Задаем, что откуда будем получать и куда оно должно выводиться
Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, nil, FVideoCaptureFilter, FBaseFilter, nil);
if FAILED(Result) then EXIT;

//Получаем интерфейс управления окном видео
Result := FGraphBuilder.QueryInterface(IID_IVideoWindow, FVideoWindow);
if FAILED(Result) then EXIT;
//Задаем стиль окна вывода
FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS);
//Накладываем окно вывода на  Panel1
FVideoWindow.put_Owner(Panel1.Handle);
//Задаем размеры окна во всю панель
FVideoRect := Panel1.ClientRect;
FVideoWindow.SetWindowPosition(FVideoRect.Left,FVideoRect.Top, FVideoRect.Right - FVideoRect.Left,FVideoRect.Bottom - FVideoRect.Top);
//показываем окно
FVideoWindow.put_Visible(TRUE);

//Запрашиваем интерфейс управления графом
Result := FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);
if FAILED(Result) then Exit;
//Запускаем отображение просмотра с вебкамер
FMediaControl.Run();
end;

procedure TVideoForm.Button2Click(Sender: TObject);
var ICINFO: TICINFO;
    res : integer;
    TMPbmiHeader: TBitmapInfo;
    TMPbmiHeader2: TBitmapInfo;
    TMPbmiIN: pBitmapInfo;
    TMPbmirOUT: pBitmapInfo;
    pDecoderBMPVideoFormat: pBitmapInfo;
begin
if not WriteThread.Suspended then
  begin
  WriteThread.Suspend;
  VideoCoDec1.CloseCompressor;
  VideoCoDec1.CloseDecompressor;
  end;

//перед вызовом функции нужно остановить граф
//SetVideoParams(FCaptureGraphBuilder as ICaptureGraphBuilder2, PIN_CATEGORY_CAPTURE, FVideoCaptureFilter as IBaseFilter);
CoderBMPVideoFormat := GetCurrentVideoFormat();
CoderCompressedVideoFormat := CoderBMPVideoFormat;

ICINFO := pICINFO(VideoCoDec1.CodecList.Items[cbxCodecs.ItemIndex])^;

//Не работает RLE, Intel 4:2:0 Video V2.50
CurrentFrameRate := 30;

//GetMem(TMPbmiIN, SizeOf(TBitMapInfo));
//CopyMemory(TMPbmiIN, @BMPVideoFormat, SizeOf(TBitMapInfo));
//GetMem(TMPbmirOUT, SizeOf(TBitMapInfo));
//CopyMemory(TMPbmirOUT, @CompressVideoFormat, SizeOf(TBitMapInfo));

if (ICINFO.fccHandler = MKFOURCC('X','V','I','D'))
  and (CoderBMPVideoFormat.bmiHeader.biCompression = bi_RGB) then
  begin
  //костыли для XVID, который не переваривает 640х480
  CoderBMPVideoFormat.bmiHeader.biHeight := 478;//эксперимент с XVID
  CoderBMPVideoFormat.bmiHeader.biSizeImage := CoderBMPVideoFormat.bmiHeader.biWidth *
                                               CoderBMPVideoFormat.bmiHeader.biHeight *
                                               round(CoderBMPVideoFormat.bmiHeader.biBitCount/8);//эксперимент с XVID
  end;
//CoderCompressedVideoFormat.bmiHeader.biWidth := CoderBMPVideoFormat.bmiHeader.biWidth;//эксперимент с XVID
//CoderCompressedVideoFormat.bmiHeader.biCompression := MKFOURCC('D', 'X', '5', '0');

TMPbmirOUT :=  VideoCoDec1.InitCompressor(ICINFO.fccHandler,
                                          CoderBMPVideoFormat,
                                          CoderCompressedVideoFormat,
                                          7500, CurrentFrameRate, 0);

if TMPbmirOUT <> nil then
  begin
//  VideoCoDec1.SetDataRate(0, 15, 0);
    
  memo1.Lines.Add('CodecName = ' + VideoCoDec1.CodecName);
  memo1.Lines.Add('FOURCC Codec.fccHandler =  ' + VideoCoDec1.FOURCCtoString(VideoCoDec1.CodecInfo.fccHandler) );
  tmpbmiHeader := VideoCoDec1.GetCompressorBitmapInfoOut;
  memo1.Lines.Add('FOURCC Codec out biCompression =  ' + VideoCoDec1.FOURCCtoString(TMPbmiHeader.bmiHeader.biCompression));

//Короче экспериментальным путем выяснено следующее:
//на вход Декомпрессора НЕЛЬЗЯ подавать TBitmapInfo с размером по умолчанию!
//Эта структура может иметь абсолютно не стандартный размер!!!
//соответственно такие строки:
//..CopyMemory(@DeCoderCompressedVideoFormat, TMPbmirOUT, VideoCoDec1.CompressOutbiSize);
//..CopyMemory(@DeCoderCompressedVideoFormat, TMPbmirOUT, TMPbmirOUT.bmiHeader.biSize + sizeof(RGBQUAD));
//применять НЕЛЬЗЯ! На вход декодера передавать СТРОГО БУФЕР!
//т.к. этот буфер может иметь неопределенный размер!


//пробуем запросить у системы каким декомпрессором воспользоваться?
//VideoCoDec1.GetDecompressorIDByCompressedHeader(@TMPbmirOUT.bmiHeader, @DeCoderBMPVideoFormat.bmiHeader);


//Иммитируем сеть:
DeCoderBMPVideoFormat := CoderBMPVideoFormat;
GetMem(pDecoderCompressedVideoFormat, VideoCoDec1.CompressOutbiSize);
CopyMemory(pDecoderCompressedVideoFormat, TMPbmirOUT, VideoCoDec1.CompressOutbiSize);

//  pDecoderBMPVideoFormat := VideoCoDec1.InitDecompressor(ICINFO.fccHandler, TMPbmirOUT^, DeCoderBMPVideoFormat,
//                                                         7500, CurrentFrameRate, 0);
//  pDecoderBMPVideoFormat := VideoCoDec1.InitDecompressor(ICINFO.fccHandler, DeCoderCompressedVideoFormat, DeCoderBMPVideoFormat,
//                                                         7500, CurrentFrameRate, 0);

  pDecoderBMPVideoFormat := VideoCoDec1.InitDecompressor(0,//ICINFO.fccHandler,
                                                         pDecoderCompressedVideoFormat^,
                                                         DeCoderBMPVideoFormat,
                                                         7500, CurrentFrameRate, 0);
//pDecoderBMPVideoFormat.bmiHeader.biCompression := 0;//возимся с XVID (не показывает 1/4 экрана)
//pDecoderBMPVideoFormat.bmiHeader.biBitCount := 32;//возимся с XVID (не показывает 1/4 экрана)
  if pDecoderBMPVideoFormat <> nil then
    begin
    CopyMemory(@DecoderBMPVideoFormat, pDecoderBMPVideoFormat, pDecoderBMPVideoFormat.bmiHeader.biSize + sizeof(RGBQUAD));
    memo1.Lines.Add('DecodecName = ' + VideoCoDec1.CodecName);
    memo1.Lines.Add('FOURCC Decodec.fccHandler =  ' + VideoCoDec1.FOURCCtoString(VideoCoDec1.CodecInfo.fccHandler) );
    tmpbmiHeader := VideoCoDec1.GetDecompressorBitmapInfoIn;
    memo1.Lines.Add('FOURCC Decodec input biCompression =  ' + VideoCoDec1.FOURCCtoString(tmpbmiHeader.bmiHeader.biCompression));
    end
  else
    begin
    memo1.Lines.Add('InitDecompressor error: ' + VideoCoDec1.TranslateICError(VideoCoDec1.LastError));
    VideoCoDec1.CloseCompressor;
    VideoCoDec1.CloseDecompressor;
    exit;
    end;
  WriteThread.Resume;
  end
else
  begin
  memo1.Lines.Add('InitCompressor error: ' + VideoCoDec1.TranslateICError(VideoCoDec1.LastError));
  VideoCoDec1.CloseCompressor;
  VideoCoDec1.CloseDecompressor;
  end;
end;

//с помощью этой функции будем грабить изображение
function TVideoForm.CaptureBitmap: HResult;

  function GetDIBLineSize(BitCount, Width: Integer): Integer;
  begin
    if BitCount = 15 then
      BitCount := 16;
    Result := ((BitCount * Width + 31) div 32) * 4;
  end;

var
  bSize: integer;
  VideoHeader: TVideoInfoHeader;
  MediaType: TAMMediaType;
  BitmapInfo, unpackBitmapInfo: TBitmapInfo;
  pDIBBuffer, pUnpackedBuffer: Pointer;
  tmp: array of byte;
  Bitmap, unPackBitmap: TBitmap;
  x, y: integer;
  r, g, b: byte;
  rt, gt, bt: byte;
  hWinDC : THandle;
  res, KeyFrame: boolean;
  PackedFrameSize: DWORD;
  pPackedFrame, pBuffer, pBuffer2: pointer;
  BIHeaderPtr: pBitmapInfoHeader;
  DIBSize: LongInt;
  CapturedBuffer: Pointer;
  CapturedBufferLength: Integer;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс фильтра перехвата изображения,
  // то завершаем работу
  if FSampleGrabber = NIL then
    begin
    LastErrorMess := 'FSampleGrabber = NIL';
    EXIT;
    end;
  // Создаем изображение
  Bitmap := TBitmap.Create;
  try
  //обнуляем память
  ZeroMemory(@MediaType, sizeof(TAMMediaType));
  // Получаем тип медиа потока на входе у фильтра перехвата
  //тут НЕПРАВИЛЬНО! Тут нам выдается не текущий медиапоток,
  //а первый из всего набора возможных режимов!

  CapturedBufferLength := 0;
  CapturedBuffer := nil;
  Result := FSampleGrabber.GetConnectedMediaType(MediaType);
  if Result <> S_OK then Exit;
  try
    if IsEqualGUID(MediaType.majortype, MEDIATYPE_Video) then
    begin
    BIHeaderPtr := Nil;
    //у нас может быть 2 варианта структуры изображения от видеодрайвера
    //1. FORMAT_VideoInfo
    if IsEqualGUID(MediaType.formattype, FORMAT_VideoInfo) then
      begin
      if MediaType.cbFormat = SizeOf(TVideoInfoHeader) then  // check size
        begin
        VideoHeader := TVideoInfoHeader(MediaType.pbFormat^);
        BIHeaderPtr := @(PVideoInfoHeader(MediaType.pbFormat)^.bmiHeader);
        ZeroMemory(@BitmapInfo, sizeof(TBitmapInfo));
        CopyMemory(@BitmapInfo.bmiHeader, BIHeaderPtr, sizeof(TBITMAPINFOHEADER));
        end
      else
        LastErrorMess := 'MediaType.cbFormat: error size TVideoInfoHeader';
      end
    else
      begin
      //1. FORMAT_VideoInfo2
      if IsEqualGUID(MediaType.formattype, FORMAT_VideoInfo2) then
        begin
        if MediaType.cbFormat = SizeOf(TVideoInfoHeader2) then  // check size
          begin
          VideoHeader := TVideoInfoHeader(MediaType.pbFormat^);
          BIHeaderPtr := @(PVideoInfoHeader2(MediaType.pbFormat)^.bmiHeader);
          ZeroMemory(@BitmapInfo, sizeof(TBitmapInfo));
          CopyMemory(@BitmapInfo.bmiHeader, BIHeaderPtr, sizeof(TBITMAPINFOHEADER));
          end
        else
          LastErrorMess := 'MediaType.cbFormat: error size TVideoInfoHeader2';
        end
      else
        LastErrorMess := 'MediaType.cbFormat: <> FORMAT_VideoInfo and <> FORMAT_VideoInfo2';
      end;
    // check, whether format is supported by TSampleGrabber
    //получили от видеодрайвера структуру заголовка BitMap
    if not Assigned(BIHeaderPtr) then
      begin
      //видеодрайвер по какой-то причине не смог вернуть заголовок BitMap
      if IsEqualGUID(MediaType.formattype, FORMAT_VideoInfo) then
        LastErrorMess := 'PVideoInfoHeader cannt return BIHeaderPtr'
      else
        LastErrorMess := 'PVideoInfoHeader2 cannt return BIHeaderPtr';
      Exit;
      end;
    //конец обработки ошибок инициализации структур

    Bitmap.Handle := CreateDIBSection(0, PBitmapInfo(BIHeaderPtr)^,
                     DIB_RGB_COLORS, pDIBBuffer, 0, 0);
    if Bitmap.Handle <> 0 then
      begin
      CapturedBufferLength := BIHeaderPtr.biSizeImage;
        try
          if pDIBBuffer = Nil then Exit;
          //теоритически драйвер уже дал нам размер захватываемого Bitmap
          DIBSize := BIHeaderPtr^.biSizeImage;
          if DIBSize = 0 then
            begin
            //однако возможен случай, что он глюканул
            with BIHeaderPtr^ do
              //тогда считаем размер данных Bitmap сами
              DIBSize := GetDIBLineSize(biBitCount, biWidth) * biHeight * biPlanes;
            end;
          // copy DIB
          if not Assigned(CapturedBuffer) then
            begin
            //параноя. Но проверим)
            //еще раз запрашиваем напрямую у фильтра размер данных Bitmap
            //вдруг драйвер говорит одно, а фильтр имеет на выходе другой формат?
            CapturedBufferLength := 0;
            Result := FSampleGrabber.GetCurrentBuffer(CapturedBufferLength, Nil);
            if (Result <> S_OK) or (CapturedBufferLength <= 0) then
              begin
              //ТУТ ДОДЕЛАТЬ! Уничтожить все что создали!
              LastErrorMess := 'GetCurrentBuffer() cannt return size of data the captured Bitmap';
              Exit;
              end;
            //проверяем, что размер данных от драйвера совпадает с размером
            //данных на выходе фильтра. Если не так, верим драйверу)
            if CapturedBufferLength > DIBSize then  // copy Min(BufferLen, DIBSize)
              CapturedBufferLength := DIBSize;
            Result := FSampleGrabber.GetCurrentBuffer(CapturedBufferLength, pDIBBuffer);
            if Result <> S_OK then
              begin
              LastErrorMess := 'GetCurrentBuffer() cannt capture Bitmap';
              Exit;
              end;
            end
          else
            begin
            //тут хз... возможно DSPACK работает с одним и тем же буфером
            //для последующего захвата?
            if CapturedBufferLength > DIBSize then  // copy Min(BufferLen, DIBSize)
              CapturedBufferLength := DIBSize;
            Move(CapturedBuffer, pDIBBuffer, CapturedBufferLength);
            end;
          Result := S_OK;
        finally
//          if Bitmap.Handle <> Bitmap.Handle then  // preserve for any changes in Graphics.pas
//            DeleteObject(Bitmap.Handle);
        end;
      end
    else
      begin
      LastErrorMess := 'CreateDIBSection FAILED';
      EXIT;
      end;
    end;
  finally
  end;

//  hWinDC := GetDC(Panel2.Handle);
  hWinDC := PaintBox1.Canvas.Handle;
  BitBlt( hWinDC, 0, 0, Bitmap.Width, Bitmap.Height, Bitmap.Canvas.Handle, 0, 0, SRCCOPY);


  try
      //Пытаемся сжать кадр
      KeyFrame := false;
      LastErrorMess := 'except PackFrame2';
      PackedFrameSize := VideoCoDec1.RequestedMaxFrameSize;
      pPackedFrame := VideoCoDec1.PackFrame( pDIBBuffer, KeyFrame, PackedFrameSize );
      x := PackedFrameSize;
      AverageSpeedCounter.AddMomentalSpeed(PackedFrameSize);
      AverageSpeedCounter.AddMomentalFps(1);
      //Все ок! Теперь если
      //не надо вызывать SeqCompressFrame! Она вызывается внутри
      //PackedFrame := VideoCodec.SeqCompressFrame( Buffer, KeyFrame, PackedFrameSize );
      if pPackedFrame <> nil then
        begin
        LastErrorMess := 'except UnpackBitmap';


//ну почему же на одном компе все работает, а если вот тут вставить сеть - не пашет!
//т.е. кодек инициализируется, но декодировать не хочет!



        //Пытаемся распаковать кадр
        pUnpackedBuffer := VideoCoDec1.UnpackFrame( pPackedFrame, KeyFrame, PackedFrameSize );
        if pUnpackedBuffer <> nil then
          begin
//В данной версии у XVID обрезает 1/3 изображения. Возможно это
//из-за того, что цвет должен кодироваться не 24 бита (3 байта на
//цвет), а 32 бита (4 байта на цвет)
//Все остальные кодеки работают.

          //1 вариант - прямое копирование. Канвас должен быть размером с Bitmap
          // ИСПОЛЬЗОВАТЬ ПО УМОЛЧАНИЮ!
          unPackBitmap := TBitmap.Create;
          pBuffer2 := nil;
          // Создаем побитовое изображение
          if DecoderBMPVideoFormat.bmiHeader.biBitCount = 24 then
            begin
            ZeroMemory(@unpackBitmapInfo, sizeof(TBitmapInfo));
            CopyMemory(@unpackBitmapInfo.bmiHeader, @VideoHeader.bmiHeader, sizeof(TBITMAPINFOHEADER));
             unPackBitmap.Handle := CreateDIBSection( unPackBitmap.Canvas.Handle, unpackBitmapInfo,
                                   IIF(unpackBitmapInfo.bmiHeader.biClrUsed = 0, DIB_RGB_COLORS, DIB_PAL_COLORS),
                                   pBuffer2, 0, 0);
            CopyMemory(pBuffer2, pUnpackedBuffer, unpackBitmapInfo.bmiHeader.biSizeImage);
            end
          else
            begin
//разобраться блять! почему тут BMPVideoFormat имеет сжатие!
            ZeroMemory(@unpackBitmapInfo, sizeof(TBitmapInfo));
            CopyMemory(@unpackBitmapInfo.bmiHeader, @DecoderBMPVideoFormat.bmiHeader, DecoderBMPVideoFormat.bmiHeader.biSize);

            unPackBitmap.Handle := CreateDIBSection( unPackBitmap.Canvas.Handle, unpackBitmapInfo,
                                   IIF(unpackBitmapInfo.bmiHeader.biClrUsed = 0, DIB_RGB_COLORS, DIB_PAL_COLORS),
                                   pBuffer2, 0, 0);
            CopyMemory(pBuffer2, pUnpackedBuffer, DecoderBMPVideoFormat.bmiHeader.biSizeImage);
            end;
//вариант 1

          hWinDC := PaintBox2.Canvas.Handle;
          BitBlt( hWinDC, 0, 0, unPackBitmap.Width, unPackBitmap.Height, unPackBitmap.Canvas.Handle, 0, 0, SRCCOPY);

          PaintBox2.Canvas.TextOut(0, 0,  'PackedFrameSize = ' + inttostr(x) + '|||||||');
          PaintBox2.Canvas.TextOut(0, 15, 'Average frame len = ' + inttostr(AverageSpeedCounter.AverageSpeed) + '|||||||');
          PaintBox2.Canvas.TextOut(0, 30, 'Average FPS = ' + inttostr(AverageSpeedCounter.AverageFPS) + '|||||||');
          PaintBox2.Canvas.TextOut(0, 45, 'Avr. speed Byte/sec = ' + inttostr(AverageSpeedCounter.AverageSpeed*AverageSpeedCounter.AverageFPS) + '|||||||');


{
          //2 вариант копировать с масштабированием, но тогда теряется цвет
          unPackBitmap := TBitmap.Create;
          ZeroMemory(@unpackBitmapInfo, sizeof(TBitmapInfo));
          CopyMemory(@unpackBitmapInfo.bmiHeader, @VideoHeader.bmiHeader, sizeof(TBITMAPINFOHEADER));
          unPackBitmap.Handle := CreateDIBSection( unPackBitmap.Canvas.Handle, unpackBitmapInfo, DIB_RGB_COLORS, pBuffer2, 0, 0);
          CopyMemory(pBuffer2, pUnpackedBuffer, unpackBitmapInfo.bmiHeader.biSizeImage);
          PaintBox2.Canvas.CopyRect(rect(0, 0, unPackBitmap.Width, unPackBitmap.Height),
                               unPackBitmap.Canvas,
                               rect(0, 0, unPackBitmap.Width, unPackBitmap.Height));
          PaintBox2.Canvas.TextOut(0, 15, 'PackedFrameSize = ' + inttostr(x) + '|||||||');
//          PaintBox2.Picture.Bitmap.Canvas.Canvas.CopyRect(rect(0, 0, unPackBitmap.Width, unPackBitmap.Height),
//                               unPackBitmap.Canvas,
//                               rect(0, 0, unPackBitmap.Width, unPackBitmap.Height));
//          PaintBox2.Picture.Bitmap.Canvas.Canvas.TextOut(0, 15, 'PackedFrameSize = ' + inttostr(x) + '|||||||');
}
{
          //3 копируем с масштабированием без потери в цвете
          //отрисовка Bitmap с масштабированием размера
          //unPackBitmap := TBitmap.Create;
          ZeroMemory(@unpackBitmapInfo, sizeof(TBitmapInfo));
          CopyMemory(@unpackBitmapInfo.bmiHeader, @VideoHeader.bmiHeader, sizeof(TBITMAPINFOHEADER));
          unPackBitmap.Handle := CreateDIBSection(unPackBitmap.Canvas.Handle, unpackBitmapInfo,
                                                  DIB_RGB_COLORS, pBuffer2, 0, 0);
          CopyMemory(pBuffer2, pUnpackedBuffer, unpackBitmapInfo.bmiHeader.biSizeImage);
          //DDDraw( PaintBox2.Canvas, 0, 0, unPackBitmap.Height, unPackBitmap.Width, unPackBitmap);
          DDDraw( PaintBox2.Canvas, 0, 0, 200, 200, unPackBitmap);
          PaintBox2.Canvas.TextOut(0, 15, 'PackedFrameSize = ' + inttostr(x) + '|||||||');
}

          unPackBitmap.free;
          end
        else
          begin
          PaintBox1.Canvas.TextOut(0, 40, 'error decompressed image: ' + VideoCoDec1.TranslateICError(VideoCoDec1.LastError));
          end;
        end
      else
        begin
        PaintBox1.Canvas.TextOut(0, 40, 'error compress image: ' + VideoCoDec1.TranslateICError(VideoCoDec1.LastError));
        end;
    except
      // В случае сбоя возвращаем ошибочный результат
      Result := E_FAIL;
    end;

  finally
    // Освобождаем память
    SetLength(tmp, 0);
    if Bitmap <> nil then FreeAndNil(Bitmap);
    FreeMediaType(@MediaType);
  end;

end;


procedure TVideoForm.DDDraw( Canvas: TCanvas; dTop, dLeft, dHeight, dWidth: Integer;
                                             Bitmap: TBitmap);
var
  lpBits  : Pointer;
  pBmpInfo: PBitmapInfo;
  nColors : Cardinal;
  hdd     : HDRAWDIB;
  BitmapStream: TMemoryStream;

  procedure SetSize;
  var
    RatioH,
    RatioW  : Extended;
  begin
    with pBmpInfo^.bmiHeader do begin
      if ( biWidth > dWidth ) or ( biHeight > dHeight ) then
        begin
          RatioH := dHeight / biHeight;
          RatioW := dWidth  / biWidth;
          if RatioH > RatioW then RatioH := RatioW;
          dHeight := Trunc( biHeight * RatioH );
          dWidth  := Trunc( biWidth  * RatioH );
          Exit;
        end;
      dHeight := biHeight;
      dWidth  := biWidth;
    end;
  end;

begin
  if Bitmap = nil then exit;
  BitmapStream := TMemoryStream.Create;
  Bitmap.SaveToStream(BitmapStream);
  pBmpInfo := PBitmapInfo( PChar( BitmapStream.Memory )
                           + SizeOf(TBitmapFileHeader) );
  with pBmpInfo^, bmiHeader do begin
    if biClrUsed = 1 then
      nColors := biClrUsed
    else
      nColors := ( 1 shl biBitCount );
    if biBitCount > 8 then
      begin
         lpBits := PChar( @bmiColors ) + Ord( biClrUsed )
                     + Ord( biCompression = BI_BITFIELDS ) * 3;
      end
    else lpBits := PChar( @bmiColors ) + nColors;
    hdd := DrawDibOpen;
    try
      DrawDibRealize( hdd, Canvas.Handle, True );
      SetSize;
      DrawDibDraw( hdd,
                   Canvas.Handle,
                   dLeft,  dTop,
                   dWidth, dHeight,
                   PBitmapInfoHeader( @bmiHeader ),
                   lpBits,
                   0, 0,
                   biWidth, biHeight,
                   DDF_HALFTONE );
    finally
      DrawDibClose( hdd );
    end;
  end;
  BitmapStream.Free;
end;

Function TVideoForm.SetVideoParams(CB_B2: ICaptureGraphBuilder2; Category: TGUID;
           fSource: IBaseFilter): HResult;
 var
 StreamConf: IAMStreamConfig;
 PAMT: PAMMediaType;
 begin
 Result := E_FAIL;
 StreamConf := nil;
 PAMT := nil;
 try
   Result:= CB_B2.FindInterface(@Category, @MEDIATYPE_Video, fSource, IID_IAMStreamConfig, StreamConf);
   if Assigned(StreamConf) then
     begin
//     StreamConf.GeTVideoFormat(PAMT);
     StreamConf.GetFormat(PAMT);
     if Assigned(PAMT) then
       begin
       if PAMT.cbFormat= sizeOf(TVideoInfoHeader) then
         begin
         PVIDEOINFOHEADER(PAMT^.pbFormat)^.bmiHeader.biWidth:= 640;//разрешение по ширине
         PVIDEOINFOHEADER(PAMT^.pbFormat)^.bmiHeader.biHeight:= 480;//разрешение по высоте
         PVIDEOINFOHEADER(PAMT^.pbFormat)^.bmiHeader.biBitCount:= 24; //rgb24
         PVIDEOINFOHEADER(PAMT^.pbFormat)^.AvgTimePerFrame:= 10000000 div 30; //25 fps
         with PVIDEOINFOHEADER(PAMT^.pbFormat)^.bmiHeader do
         PAMT^.lSampleSize := ((biWidth + 3) and (not (3))) * biHeight * biBitCount shr 3;
         PVIDEOINFOHEADER(PAMT^.pbFormat)^.bmiHeader.biSizeImage:= PAMT^.lSampleSize;
       end;
//     Result:= StreamConf.SeTVideoFormat(PAMT^)
     Result:= StreamConf.SetFormat(PAMT^)
     end;
   end;
   result:= S_OK;
 except
   on E: Exception do
   MessageBox(0, PChar(E.Message), '', MB_OK or MB_ICONERROR);
   end;
   StreamConf:= nil;
   if Assigned(PAMT) then
   DeleteMediaType(PAMT);
 end;

// Функция DeleteMediaType из модуля DSUtil пакета DSPack.

 //Пример вызова функции
 //============================================================
 //перед вызовом функции нужно остановить граф
// SetVideoParams(FilterGraph as ICaptureGraphBuilder2, PIN_CATEGORY_CAPTURE, SourceFilter as IBaseFilter);
 //после вызова нужно запустить граф снова
 //============================================================

procedure TVideoForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  SysDev.Free;
  FilterGraph.ClearGraph;
  FilterGraph.Active := false;
end;

end.
