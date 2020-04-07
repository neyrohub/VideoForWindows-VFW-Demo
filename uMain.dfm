object VideoForm: TVideoForm
  Left = 0
  Top = 0
  Caption = 'Video Capture Devices'
  ClientHeight = 624
  ClientWidth = 1199
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poDesigned
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 120
  TextHeight = 16
  object PaintBox1: TPaintBox
    Left = 935
    Top = 363
    Width = 254
    Height = 208
  end
  object PaintBox2: TPaintBox
    Left = 462
    Top = 0
    Width = 731
    Height = 356
  end
  object ListBox1: TListBox
    Left = 10
    Top = 409
    Width = 444
    Height = 45
    ItemHeight = 16
    TabOrder = 0
  end
  object Panel1: TPanel
    Left = 10
    Top = -1
    Width = 444
    Height = 354
    Caption = 'Panel1'
    TabOrder = 1
  end
  object Button1: TButton
    Left = 10
    Top = 361
    Width = 444
    Height = 40
    Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1072' '#1082#1072#1084#1077#1088#1099
    TabOrder = 2
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 473
    Top = 361
    Width = 446
    Height = 40
    Caption = #1055#1091#1089#1082' '#1087#1086#1090#1086#1082#1072
    TabOrder = 3
    OnClick = Button2Click
  end
  object cbxCodecs: TComboBox
    Left = 10
    Top = 545
    Width = 442
    Height = 24
    ItemHeight = 16
    TabOrder = 4
    Text = 'cbxCodecs'
  end
  object Memo1: TMemo
    Left = 473
    Top = 414
    Width = 446
    Height = 158
    Lines.Strings = (
      #1042' '#1076#1072#1085#1085#1086#1081' '#1074#1077#1088#1089#1080#1080' '#1091' XVID '#1086#1073#1088#1077#1079#1072#1077#1090' 1/3 '#1080#1079#1086#1073#1088#1072#1078#1077#1085#1080#1103'. '#1042#1086#1079#1084#1086#1078#1085#1086' '#1101#1090#1086' '
      #1080#1079'-'#1079#1072' '#1090#1086#1075#1086', '#1095#1090#1086' '#1094#1074#1077#1090' '#1076#1086#1083#1078#1077#1085' '#1082#1086#1076#1080#1088#1086#1074#1072#1090#1100#1089#1103' '#1085#1077' 24 '#1073#1080#1090#1072' (3 '#1073#1072#1081#1090#1072' '#1085#1072' '
      #1094#1074#1077#1090'), '#1072' 32 '#1073#1080#1090#1072' (4 '#1073#1072#1081#1090#1072' '#1085#1072' '#1094#1074#1077#1090')')
    TabOrder = 5
  end
  object PinInterfaces: TListBox
    Left = 10
    Top = 462
    Width = 444
    Height = 76
    ItemHeight = 16
    TabOrder = 6
  end
  object Button3: TButton
    Left = 10
    Top = 581
    Width = 444
    Height = 31
    Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1072' '#1082#1086#1076#1077#1082#1072
    TabOrder = 7
    OnClick = Button3Click
  end
  object FilterGraph: TFilterGraph
    Mode = gmCapture
    GraphEdit = True
    LinearVolume = True
    Left = 8
    Top = 8
  end
  object MainMenu1: TMainMenu
    Left = 8
    Top = 104
  end
  object Filter: TFilter
    BaseFilter.data = {00000000}
    FilterGraph = FilterGraph
    Left = 8
    Top = 40
  end
  object SampleGrabber: TSampleGrabber
    FilterGraph = FilterGraph
    MediaType.data = {
      7669647300001000800000AA00389B717DEB36E44F52CE119F530020AF0BA770
      FFFFFFFF0000000001000000809F580556C3CE11BF0100AA0055595A00000000
      0000000000000000}
    Left = 8
    Top = 72
  end
end
