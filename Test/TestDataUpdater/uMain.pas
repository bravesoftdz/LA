﻿unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  LA.Data.Updater, LA.Net.Connector.Http,
  LA.Data.Link.Sensor, LA.Data.Sensor;

type
  TForm1 = class(TForm)
    bStart: TButton;
    bStop: TButton;
    bCreate: TButton;
    aLog: TMemo;
    bTestSessionCache: TButton;
    bTestNoSID: TButton;
    bTestMany: TButton;
    eItemCount: TEdit;
    procedure bStartClick(Sender: TObject);
    procedure bCreateClick(Sender: TObject);
    procedure bStopClick(Sender: TObject);
    procedure bTestSessionCacheClick(Sender: TObject);
    procedure bTestNoSIDClick(Sender: TObject);
    procedure bTestManyClick(Sender: TObject);
    procedure aLogDblClick(Sender: TObject);
  private
    FConnector: TDCHttpConnector;
    FUpdater: TDataUpdater;
    FSensor: TDCSensor;
    procedure Log(const aMsg: string);
  public
    procedure DoUpdate(Sender: TObject);
  end;

var
  Form1: TForm1;

implementation

uses
  System.Diagnostics,
  LA.Types.Monitoring;

{$R *.dfm}

procedure TForm1.aLogDblClick(Sender: TObject);
begin
  alog.Clear;
end;

procedure TForm1.bCreateClick(Sender: TObject);
begin
  FUpdater := TDataUpdater.Create(Self);
  FUpdater.OnUpdate := DoUpdate;
  FUpdater.Interval := 1000;

  FConnector := TDCHttpConnector.Create(Self);
  FConnector.Address := 'https://dc.tdc.org.ua';
//  FConnector.Address := 'localhost:89';
//  FConnector.Address := 'elcomteh.ddns.mksat.net:5153';
  FConnector.UserName := 'demo';
  FConnector.Password := 'demo';

  FSensor := TDCSensor.Create(Self);
  FSensor.ID := '4';

  FUpdater.Attach(TDCSensorLink.Create(FSensor));

  FUpdater.Connector := FConnector;
end;

procedure TForm1.bStartClick(Sender: TObject);
begin
  FUpdater.Active := True;
end;

procedure TForm1.bStopClick(Sender: TObject);
begin
  FUpdater.Active := False;
end;

procedure TForm1.bTestManyClick(Sender: TObject);
var
  aSIDs: TSIDArr;
  s: TStopwatch;
  r: string;
begin
  SetLength(aSIDs, StrToInt(eItemCount.Text));
  for var i := 0 to High(aSIDs) do
    aSIDs[i] := (i+1).ToString;


//  log(FConnector.SensorsDataAsText(aSIDs));
  s := TStopwatch.StartNew;
  r := FConnector.SensorsDataAsText(aSIDs);
  log(Format('time, ms = %d : size, byte = %d', [s.ElapsedMilliseconds, r.Length]));

end;

procedure TForm1.bTestNoSIDClick(Sender: TObject);
var
  s: TStopwatch;
  r: string;
begin
//  log(FConnector.SensorsDataAsText([]));
  s := TStopwatch.StartNew;
  r := FConnector.SensorsDataAsText([]);
  log(Format('time, ms = %d : size, byte = %d', [s.ElapsedMilliseconds, r.Length]));
end;

procedure TForm1.bTestSessionCacheClick(Sender: TObject);
begin
  log(FConnector.SensorsDataAsText(['1','2','3']));
  log(FConnector.SensorsDataAsText([]));
  log(FConnector.SensorsDataAsText([]));
  log(FConnector.SensorsDataAsText(['1','2','3','4']));
  log(FConnector.SensorsDataAsText([]));
  log(FConnector.SensorsDataAsText([]));
end;

procedure TForm1.DoUpdate(Sender: TObject);
begin
  aLog.Lines.Add(FormatDateTime('hh:mm:ss.zzz', Now) +
    ' : ' + FSensor.Value +
    ' : ' + FormatDateTime('hh:mm:ss.zzz', FSensor.Timestamp));
end;

procedure TForm1.Log(const aMsg: string);
begin
  aLog.Lines.Add(FormatDateTime('hh:mm:ss.zzz', Now) + ': ' + aMsg);
end;

end.
