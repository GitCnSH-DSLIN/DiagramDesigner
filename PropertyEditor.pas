unit PropertyEditor;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, DiagramBase, StdCtrls, ComCtrls, ExtCtrls, ValueEdits, ColorDialog,
  LinarBitmap, DesignerSetup, StyleForm, Buttons, FileUtils, WMFLoader, MathUtils,
  PanelFrame;

type
  TPropertyEditorForm = class(TStyleForm)
    Panel: TPanelFrame;
    OkButton: TButton;
    CancelButton: TButton;
    PageControl: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    ScrollBox1: TScrollBox;
    Panel1: TPanel;
    NameEdit: TEdit;
    Panel2: TPanel;
    TextEdit: TEdit;
    Panel4: TPanel;
    TextYAlignBox: TComboBox;
    Panel3: TPanel;
    TextXAlignBox: TComboBox;
    Panel8: TPanel;
    HeightEditLabel: TLabel;
    HeightEdit: TFloatEdit;
    Panel9: TPanel;
    WidthEditLabel: TLabel;
    WidthEdit: TFloatEdit;
    Panel10: TPanel;
    TopEditLabel: TLabel;
    TopEdit: TFloatEdit;
    Panel11: TPanel;
    LeftEditLabel: TLabel;
    LeftEdit: TFloatEdit;
    ScrollBox2: TScrollBox;
    Panel5: TPanel;
    LineWidthEditLabel: TLabel;
    LineWidthEdit: TFloatEdit;
    Panel12: TPanel;
    LineStartBox: TComboBox;
    Panel13: TPanel;
    LineEndBox: TComboBox;
    Panel7: TPanel;
    Button1: TButton;
    LineColorPanel: TPanel;
    Panel6: TPanel;
    Button2: TButton;
    FillColorPanel: TPanel;
    LineStartEdit: TIntegerEdit;
    LineEndEdit: TIntegerEdit;
    Panel14: TPanel;
    TextColorPanel: TPanel;
    Panel15: TPanel;
    EditBitmapButton: TButton;
    ExportBitmapButton: TButton;
    Panel16: TPanel;
    HalftoneCheckBox: TCheckBox;
    Panel17: TPanel;
    ExportMetafileButton: TButton;
    Panel18: TPanel;
    LayoutBox: TComboBox;
    PanelLinks: TPanel;
    EditLinksButton: TButton;
    ClearLinksButton: TButton;
    Panel19: TPanel;
    Label1: TLabel;
    AngleEdit: TFloatEdit;
    Panel20: TPanel;
    LineStyleBox: TComboBox;
    BoundsPanel: TPanel;
    InnerBoundsBox: TCheckBox;
    Panel21: TPanel;
    MarginEditLabel: TLabel;
    MarginEdit: TFloatEdit;
    PanelAnchors: TPanel;
    LeftAnchorBox: TCheckBox;
    RightAnchorBox: TCheckBox;
    TopAnchorBox: TCheckBox;
    BottomAnchorBox: TCheckBox;
    Panel22: TPanel;
    RadiusEditLabel: TLabel;
    CornerRadiusEdit: TFloatEdit;
    Panel23: TPanel;
    CurveTypeBox: TComboBox;
    HorzScaleAnchorBox: TCheckBox;
    VertScaleAnchorBox: TCheckBox;
    Panel24: TPanel;
    Label2: TLabel;
    AlphaValueEdit: TFloatEdit;
    Panel25: TPanel;
    ColorKeyButton: TButton;
    procedure ColorPanelClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure EditBitmapButtonClick(Sender: TObject);
    procedure ExportBitmapButtonClick(Sender: TObject);
    procedure ExportMetafileButtonClick(Sender: TObject);
    procedure NameEditChange(Sender: TObject);
    procedure TextEditChange(Sender: TObject);
    procedure TextXAlignBoxChange(Sender: TObject);
    procedure TextYAlignBoxChange(Sender: TObject);
    procedure PositionChangeValue(Sender: TObject);
    procedure LineWidthEditChangeValue(Sender: TObject);
    procedure LineStartBoxChange(Sender: TObject);
    procedure LineEndBoxChange(Sender: TObject);
    procedure HalftoneCheckBoxClick(Sender: TObject);
    procedure LayoutBoxChange(Sender: TObject);
    procedure EditLinksButtonClick(Sender: TObject);
    procedure ClearLinksButtonClick(Sender: TObject);
    procedure AngleEditChangeValue(Sender: TObject);
    procedure LineStyleBoxChange(Sender: TObject);
    procedure InnerBoundsBoxClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MarginEditChangeValue(Sender: TObject);
    procedure AnchorBoxClick(Sender: TObject);
    procedure CornerRadiusEditChangeValue(Sender: TObject);
    procedure CurveTypeBoxChange(Sender: TObject);
    procedure AlphaValueEditChangeValue(Sender: TObject);
    procedure ColorKeyButtonClick(Sender: TObject);
  private
    Bitmap, LocalBitmap, AlphaChannel, LocalAlphaChannel : TLinearBitmap;
    Metafile : TMetafile;
    PropertiesModified : TObjectProperties;
    Links : TFloatPointArray;
    SingleObject : TBaseObject;
  public
    class function Execute(EditObject: TBaseObject; const Options: TDesignerSetup; ObjectInGroup: Boolean): Boolean; overload;
    class function Execute(EditObjects: TBaseObjectList; const Options: TDesignerSetup): Boolean; overload;
  end;

resourcestring
  rsDLinkPointsDefined = '%d link points defined';
  rsEditingImage = 'Editing image...';
  rsDone = 'Done';
  rsCancel = 'Cancel';
  rsErrorRunningImageAnalyzer = 'Error running Image Analyzer';
  rsDownload = 'Download';
  rsLegacy = 'Legacy';
  rsLineSegments = 'Line segments';

implementation

{$R *.dfm}

uses LineObject, Main, Math, Types, ShapeObject, LinkEditor, FlowchartObject, PNGLoader;

//==============================================================================================================================
// TPropertyEditorForm
//==============================================================================================================================

            // -1  Left
            //  0  Block left
            //  1  Right
            //  2  Center
            //  3  Block right
const
  AlignmentToListIndex      : array[TTextAlign] of Integer = (0,3,2,1,4);
  AlignmentToBlockListIndex : array[TTextAlign] of Integer = (0,0,2,1,2);

  ListIndexToAlignment      : array[0..4] of Integer = (-1,2,1,0,3);
  BlockListIndexToAlignment : array[0..2] of Integer = (0,2,3);

var
  ActivePropertyPage : Integer = 0;

class function TPropertyEditorForm.Execute(EditObject: TBaseObject; const Options: TDesignerSetup; ObjectInGroup: Boolean): Boolean;
var
  Properties, ModifiedProperties : TObjectProperties;
  PropertyIndex : TObjectProperty;
  I : Integer;
  TempRect, PosRect : TRect;
  S : Single;
  ObjectAnchors : TObjectAnchors;
begin
  Properties:=EditObject.ValidProperties;
  with Create(nil) do
  try
    if EditObject is TPropertyObject then
      Caption:=Caption+' ('+IntToStr(TPropertyObject(EditObject).List.SelectCount)+' objects)'
    else
      SingleObject:=EditObject;

    // Set up properties
    if opName in Properties then NameEdit.Text:=PString(EditObject.Properties[opName])^
    else NameEdit.Parent.Hide;

    if opText in Properties then TextEdit.Text:=PString(EditObject.Properties[opText])^
    else TextEdit.Parent.Hide;

    if opPosition in Properties then with Options do
    begin
      LeftEdit.FormatString:=DisplayUnitFormat[DisplayUnits];
      TopEdit.FormatString:=DisplayUnitFormat[DisplayUnits];
      WidthEdit.FormatString:=DisplayUnitFormat[DisplayUnits];
      HeightEdit.FormatString:=DisplayUnitFormat[DisplayUnits];

      LeftEditLabel.Caption:=DisplayUnitName[DisplayUnits];
      TopEditLabel.Caption:=DisplayUnitName[DisplayUnits];
      WidthEditLabel.Caption:=DisplayUnitName[DisplayUnits];
      HeightEditLabel.Caption:=DisplayUnitName[DisplayUnits];

      with PRect(EditObject.Properties[opPosition])^ do
      begin
        LeftEdit.Value:=Left/DisplayUnitSize[DisplayUnits];
        TopEdit.Value:=Top/DisplayUnitSize[DisplayUnits];
        WidthEdit.Value:=(Right-Left)/DisplayUnitSize[DisplayUnits];
        HeightEdit.Value:=(Bottom-Top)/DisplayUnitSize[DisplayUnits];
      end;
    end
    else
    begin
      LeftEdit.Parent.Hide;
      TopEdit.Parent.Hide;
      WidthEdit.Parent.Hide;
      HeightEdit.Parent.Hide;
    end;

    if opTextXAlign in Properties then
    begin
      if opBlockAlignOnly in Properties then
      begin
        TextXAlignBox.Items.Delete(2);
        TextXAlignBox.Items.Delete(0);
        TextXAlignBox.Items.Move(0,1);
        TextXAlignBox.ItemIndex:=AlignmentToBlockListIndex[EditObject.Properties[opTextXAlign]];
      end
      else TextXAlignBox.ItemIndex:=AlignmentToListIndex[EditObject.Properties[opTextXAlign]];
    end
    else TextXAlignBox.Parent.Hide;
    if opTextYAlign in Properties then TextYAlignBox.ItemIndex:=EditObject.Properties[opTextYAlign]+1
    else TextYAlignBox.Parent.Hide;

    if opMargin in Properties then MarginEdit.Value:=EditObject.Properties[opMargin]/(DesignerDPpoint/4)
    else MarginEdit.Parent.Hide;

    if opLineWidth in Properties then LineWidthEdit.Value:=EditObject.Properties[opLineWidth]/(DesignerDPpoint/4)
    else LineWidthEdit.Parent.Hide;

    if opLineColor in Properties then SetColorPanelColor(LineColorPanel,EditObject.Properties[opLineColor])
    else LineColorPanel.Parent.Hide;

    if opFillColor in Properties then SetColorPanelColor(FillColorPanel,EditObject.Properties[opFillColor])
    else FillColorPanel.Parent.Hide;

    if opTextColor in Properties then SetColorPanelColor(TextColorPanel,EditObject.Properties[opTextColor])
    else TextColorPanel.Parent.Hide;

    if opLineStart in Properties then
    begin
      for I:=Low(LineEnds) to High(LineEnds) do
        LineStartBox.Items.AddObject(LoadResString(LineEndNames[I]),TObject(LineEnds[I]));
      LineStartBox.ItemIndex:=LineStartBox.Items.IndexOfObject(TObject(Lo(EditObject.Properties[opLineStart])));
      if LineStartBox.ItemIndex<>0 then LineStartEdit.Value:=Hi(EditObject.Properties[opLineStart]);
    end
    else LineStartBox.Parent.Hide;

    if opLineEnd in Properties then
    begin
      for I:=Low(LineEnds) to High(LineEnds) do
        LineEndBox.Items.AddObject(LoadResString(LineEndNames[I]),TObject(LineEnds[I]));
      LineEndBox.ItemIndex:=LineEndBox.Items.IndexOfObject(TObject(Lo(EditObject.Properties[opLineEnd])));
      if LineEndBox.ItemIndex<>0 then LineEndEdit.Value:=Hi(EditObject.Properties[opLineEnd]);
    end
    else LineEndBox.Parent.Hide;

    if opLineStyle in Properties then
    begin
      Assert(Length(LineStyles)=LineStyleBox.Items.Count);
      for I:=Low(LineStyles) to High(LineStyles) do
        LineStyleBox.Items.Objects[I]:=TObject(LineStyles[I]);
      LineStyleBox.ItemIndex:=LineStyleBox.Items.IndexOfObject(TObject(Lo(EditObject.Properties[opLineStyle])));
    end
    else LineStyleBox.Parent.Hide;

    if opCornerRadius in Properties then with Options do
    begin
      RadiusEditLabel.Caption:=DisplayUnitName[DisplayUnits];
      CornerRadiusEdit.Value:=EditObject.Properties[opCornerRadius]/DisplayUnitSize[DisplayUnits];
    end
    else CornerRadiusEdit.Parent.Hide;

    if opRectangleType in Properties then
    begin
      for I:=Low(FlowchartObjectLayout) to High(FlowchartObjectLayout) do
        LayoutBox.Items.AddObject(LoadResString(FlowchartObjectLayoutNames[I]),TObject(FlowchartObjectLayout[I]));
      LayoutBox.ItemIndex:=LayoutBox.Items.IndexOfObject(TObject(EditObject.Properties[opRectangleType]));
    end
    else LayoutBox.Parent.Hide;

    if opCurveType in Properties then
    begin
      CurveTypeBox.Items.Add('Catmull-Rom');
      CurveTypeBox.Items.Add(rsLegacy);
      CurveTypeBox.Items.Add('B�zier');
      CurveTypeBox.Items.Add(rsLineSegments);
      CurveTypeBox.ItemIndex:=EditObject.Properties[opCurveType];
    end
    else CurveTypeBox.Parent.Hide;

    if opAngle in Properties then AngleEdit.Value:=PSingle(EditObject.Properties[opAngle])^*(-180/Pi)
    else AngleEdit.Parent.Hide;

    if opMetafile in Properties then Metafile:=TMetafile(EditObject.Properties[opMetafile])
    else ExportMetafileButton.Parent.Hide;

    if opBitmap in Properties then
    begin
      Bitmap:=TLinearBitmap(EditObject.Properties[opBitmap]);
      if opAlphaBitmap in Properties then AlphaChannel:=TLinearBitmap(EditObject.Properties[opAlphaBitmap]);
    end
    else EditBitmapButton.Parent.Hide;

    if not ((opBitmap in Properties) and (opAlphaBitmap in Properties)) then
      ColorKeyButton.Parent.Hide;

    if opHalftoneStretch in Properties then HalftoneCheckBox.Checked:=EditObject.Properties[opHalftoneStretch]<>0
    else HalftoneCheckBox.Parent.Hide;

    if opAlphaValue in Properties then AlphaValueEdit.Value:=EditObject.Properties[opAlphaValue]/255*100
    else AlphaValueEdit.Parent.Hide;

    if opCustomLinks in Properties then
    begin
      Links:=Copy(PFloatPointArray(EditObject.Properties[opCustomLinks])^);
      PanelLinks.Caption:=Format(rsDLinkPointsDefined,[Length(Links)]);
    end
    else PanelLinks.Hide;

    if opAnchors in Properties then
    begin
      ObjectAnchors:=PObjectAnchors(EditObject.Properties[opAnchors])^;
      LeftAnchorBox.Checked:=oaLeft in ObjectAnchors;
      RightAnchorBox.Checked:=oaRight in ObjectAnchors;
      TopAnchorBox.Checked:=oaTop in ObjectAnchors;
      BottomAnchorBox.Checked:=oaBottom in ObjectAnchors;
      HorzScaleAnchorBox.Checked:=oaHorzScale in ObjectAnchors;
      VertScaleAnchorBox.Checked:=oaVertScale in ObjectAnchors;
      if opScalingAnchorsOnly in Properties then
      begin
        LeftAnchorBox.Enabled:=False;
        RightAnchorBox.Enabled:=False;
        TopAnchorBox.Enabled:=False;
        BottomAnchorBox.Enabled:=False;
      end;
      if not ObjectInGroup then PanelAnchors.Font.Color:=clGrayText;
    end
    else PanelAnchors.Hide;

    if opBoundsOptions in Properties then InnerBoundsBox.Checked:=EditObject[opBoundsOptions]<>0
    else BoundsPanel.Hide;

    PropertiesModified:=[];

    // Show form
    Result:=(ShowModal=mrOk) and (PropertiesModified<>[]);
    ActivePropertyPage:=PageControl.ActivePageIndex;

    if Result then
    begin
      if opName in PropertiesModified then PString(EditObject.Properties[opName])^:=NameEdit.Text;

      if opText in PropertiesModified then PString(EditObject.Properties[opText])^:=TextEdit.Text;

      if opPosition in PropertiesModified then with Options do
      begin
        PosRect:=Bounds(
          Round(LeftEdit.Value*DisplayUnitSize[DisplayUnits]),
          Round(TopEdit.Value*DisplayUnitSize[DisplayUnits]),
          Round(WidthEdit.Value*DisplayUnitSize[DisplayUnits]),
          Round(HeightEdit.Value*DisplayUnitSize[DisplayUnits]));
        EditObject.Properties[opPosition]:=Integer(@PosRect);
      end;

      if opTextXAlign in PropertiesModified then
      begin
        if opBlockAlignOnly in Properties then
          EditObject.Properties[opTextXAlign]:=BlockListIndexToAlignment[TextXAlignBox.ItemIndex]
        else
          EditObject.Properties[opTextXAlign]:=ListIndexToAlignment[TextXAlignBox.ItemIndex];
      end;

      if opMargin in PropertiesModified then EditObject.Properties[opMargin]:=Round(MarginEdit.Value*(DesignerDPpoint/4));

      if opTextYAlign in PropertiesModified then EditObject.Properties[opTextYAlign]:=TextYAlignBox.ItemIndex-1;

      if opLineWidth in PropertiesModified then EditObject.Properties[opLineWidth]:=Round(LineWidthEdit.Value*(DesignerDPpoint/4));

      if opLineColor in PropertiesModified then if LineColorPanel.Color=clBtnFace then EditObject.Properties[opLineColor]:=clNone
      else EditObject.Properties[opLineColor]:=LineColorPanel.Color;

      if opFillColor in PropertiesModified then if FillColorPanel.Color=clBtnFace then EditObject.Properties[opFillColor]:=clNone
      else EditObject.Properties[opFillColor]:=FillColorPanel.Color;

      if opTextColor in PropertiesModified then EditObject.Properties[opTextColor]:=TextColorPanel.Color;

      if opLineStart in PropertiesModified then
      begin
        if LineStartBox.ItemIndex<=0 then EditObject.Properties[opLineStart]:=0
        else EditObject.Properties[opLineStart]:=Integer(LineStartBox.Items.Objects[LineStartBox.ItemIndex]) or (LineStartEdit.Value shl 8);
      end;

      if opLineEnd in PropertiesModified then
      begin
        if LineEndBox.ItemIndex<=0 then EditObject.Properties[opLineEnd]:=0
        else EditObject.Properties[opLineEnd]:=Integer(LineEndBox.Items.Objects[LineEndBox.ItemIndex]) or (LineEndEdit.Value shl 8);
      end;

      if opLineStyle in PropertiesModified then
      begin
        if LineStyleBox.ItemIndex<=0 then EditObject.Properties[opLineStyle]:=lsSolid
        else EditObject.Properties[opLineStyle]:=Integer(LineStyleBox.Items.Objects[LineStyleBox.ItemIndex]);
      end;

      if opCornerRadius in PropertiesModified then
        EditObject.Properties[opCornerRadius]:=Round(CornerRadiusEdit.Value*DisplayUnitSize[Options.DisplayUnits]);

      if opRectangleType in PropertiesModified then
        EditObject.Properties[opRectangleType]:=Integer(LayoutBox.Items.Objects[LayoutBox.ItemIndex]);

      if opCurveType in PropertiesModified then
        EditObject.Properties[opCurveType]:=Integer(CurveTypeBox.ItemIndex);

      if (opBitmap in PropertiesModified) and Assigned(LocalBitmap) then EditObject.Properties[opBitmap]:=Integer(LocalBitmap);

      if (opAlphaBitmap in PropertiesModified) then EditObject.Properties[opAlphaBitmap]:=Integer(LocalAlphaChannel);

      if opHalftoneStretch in PropertiesModified then EditObject.Properties[opHalftoneStretch]:=Byte(HalftoneCheckBox.Checked);

      if opAlphaValue in PropertiesModified then EditObject.Properties[opAlphaValue]:=Round(AlphaValueEdit.Value/100*255);

      if opCustomLinks in PropertiesModified then EditObject.Properties[opCustomLinks]:=Integer(@Links);

      if opAnchors in PropertiesModified then
      begin
        ObjectAnchors:=[];
        if LeftAnchorBox.Checked then Include(ObjectAnchors,oaLeft);
        if RightAnchorBox.Checked then Include(ObjectAnchors,oaRight);
        if TopAnchorBox.Checked then Include(ObjectAnchors,oaTop);
        if BottomAnchorBox.Checked then Include(ObjectAnchors,oaBottom);
        if HorzScaleAnchorBox.Checked then Include(ObjectAnchors,oaHorzScale);
        if VertScaleAnchorBox.Checked then Include(ObjectAnchors,oaVertScale);
        PObjectAnchors(EditObject.Properties[opAnchors])^:=ObjectAnchors;
      end;

      if opAngle in PropertiesModified then
      begin
        S:=AngleEdit.Value*(-Pi/180);
        EditObject.Properties[opAngle]:=Integer(@S);
      end;

      if opBoundsOptions in PropertiesModified then EditObject.Properties[opBoundsOptions]:=Byte(InnerBoundsBox.Checked);

      // Edit multiple objects
      if EditObject is TPropertyObject then with TPropertyObject(EditObject) do
      begin
        for I:=0 to List.Count-1 do if List.Objects[I].Selected then
        begin
          ModifiedProperties:=PropertiesModified*List.Objects[I].ValidProperties;
          if opPosition in ModifiedProperties then with PRect(Values[opPosition])^ do
          begin
            TempRect:=PRect(List.Objects[I].Properties[opPosition])^;
            if Left<>Position.Left then
            begin
              TempRect.Right:=Left+TempRect.Right-TempRect.Left;
              TempRect.Left:=Left;
            end;
            if Top<>Position.Top then
            begin
              TempRect.Bottom:=Top+TempRect.Bottom-TempRect.Top;
              TempRect.Top:=Top;
            end;
            if Right-Left<>Position.Right-Position.Left then TempRect.Right:=TempRect.Left+Right-Left;
            if Bottom-Top<>Position.Bottom-Position.Top then TempRect.Bottom:=TempRect.Top+Bottom-Top;
            List.Objects[I].Properties[opPosition]:=Integer(@TempRect);
            Exclude(ModifiedProperties,opPosition);
          end;
          for PropertyIndex:=Low(PropertyIndex) to High(PropertyIndex) do if PropertyIndex in ModifiedProperties then
            List.Objects[I].Properties[PropertyIndex]:=Values[PropertyIndex];
        end;
      end;
    end;
  finally
    LocalBitmap.Free;
    LocalAlphaChannel.Free;
    Free;
  end;
end;

class function TPropertyEditorForm.Execute(EditObjects: TBaseObjectList; const Options: TDesignerSetup): Boolean;
var
  PropertyObject : TPropertyObject;
  CurProperties : TObjectProperties;
  PropertyIndex : TObjectProperty;
  Count, I : Integer;
begin
  Count:=EditObjects.SelectCount;
  if Count=0 then Result:=False
  else if Count=1 then Result:=Execute(EditObjects.LastSelected,Options,False)
  else
  begin
    PropertyObject:=TPropertyObject.Create;
    with PropertyObject do
    try
      List:=EditObjects;
      // Create "object" with properties from all selected objects
      for I:=0 to List.Count-1 do if List.Objects[I].Selected then
      begin
        CurProperties:=List.Objects[I].ValidProperties-Valid;
        for PropertyIndex:=Low(PropertyIndex) to High(PropertyIndex) do
          if PropertyIndex in CurProperties then
            Properties[PropertyIndex]:=List.Objects[I].Properties[PropertyIndex];
      end;
      if opPosition in Valid then Position:=PRect(Values[opPosition])^;
      Result:=Execute(PropertyObject,Options,False);
    finally
      PropertyObject.Free;
    end;
  end;
end;

procedure TPropertyEditorForm.FormShow(Sender: TObject);

  function FormatScrollbox(ScrollBox: TScrollBox): Boolean;
  var
    I : Integer;
  begin
    Result:=False;
    ScrollBox.BorderStyle:=bsNone;
    ScrollBox.HorzScrollBar.Tracking:=True;
    ScrollBox.VertScrollBar.Tracking:=True;
    for I:=0 to ScrollBox.ControlCount-1 do with TPanel(ScrollBox.Controls[I]) do if Visible then
    begin
      Result:=True;
      Caption:=' '+Caption+':';
      BevelOuter:=bvNone;
    end;
  end;

begin
  UseBackgroundTheme:=True;
  FormatScrollbox(ScrollBox1);
  TabSheet2.TabVisible:=FormatScrollbox(ScrollBox2);

  if (ActivePropertyPage<>0) and PageControl.Pages[ActivePropertyPage].TabVisible then
  begin
    PageControl.ActivePageIndex:=ActivePropertyPage;
    ActiveControl:=PageControl.ActivePage;
  end
  else
  begin
    PageControl.ActivePageIndex:=0;
    ActiveControl:=NameEdit;
  end;
end;

procedure TPropertyEditorForm.ColorPanelClick(Sender: TObject);
var
  DialogColor : TColor;
begin
  DialogColor:=TPanel(Sender).Color;
  if DialogColor=clBtnFace then DialogColor:=clBlack;
  if ShowColorDialog(DialogColor) then
  begin
    SetColorPanelColor(TPanel(Sender),DialogColor);
    if Sender=LineColorPanel then Include(PropertiesModified,opLineColor)
    else if Sender=FillColorPanel then Include(PropertiesModified,opFillColor)
    else if Sender=TextColorPanel then Include(PropertiesModified,opTextColor)
    else Assert(False);
  end;
end;

procedure TPropertyEditorForm.Button1Click(Sender: TObject);
begin
  SetColorPanelColor(LineColorPanel,clNone);
  Include(PropertiesModified,opLineColor);
end;

procedure TPropertyEditorForm.Button2Click(Sender: TObject);
begin
  SetColorPanelColor(FillColorPanel,clNone);
  Include(PropertiesModified,opFillColor);
end;

procedure TPropertyEditorForm.EditBitmapButtonClick(Sender: TObject);
var
  FileName : string;
begin
  if LocalBitmap=nil then LocalBitmap:=TLinearBitmap.Create(Bitmap);
  SetLength(FileName,MAX_PATH);
  SetLength(FileName,GetTempPath(Length(FileName),PChar(FileName)));
  FileName:=ForceBackslash(FileName)+'Designer bitmap '+IntToStr(GetTickCount)+'.png';
  Screen.Cursor:=crHourGlass;
  try
    if LocalAlphaChannel<>nil then PNGLoader.Default.AlphaChannel:=LocalAlphaChannel
    else PNGLoader.Default.AlphaChannel:=AlphaChannel;
    try
      LocalBitmap.SaveToFile(FileName);
    finally
      PNGLoader.Default.AlphaChannel:=nil;
    end;
    if ExecuteFile(MainForm.AnalyzerPath+ImageAnalyzer,FileName)>32 then
    begin
      Sleep(2000);
      if MessageDlgStr(rsEditingImage,mtConfirmation,[rsDone,rsCancel])=1 then
      try
        PNGLoader.Default.ExtraInfo:=True;
        try
          LocalBitmap.LoadFromFile(FileName);
          if (PNGLoader.Default.AlphaChannel=nil) and (PNGLoader.Default.TransparentColor>=0) then
            PNGLoader.Default.AlphaChannel:=CreateAlphaChannelFromColorKey(LocalBitmap,PNGLoader.Default.TransparentColor);
          LocalAlphaChannel.Free;
          LocalAlphaChannel:=PNGLoader.Default.AlphaChannel;
          PNGLoader.Default.AlphaChannel:=nil;
        finally
          PNGLoader.Default.ExtraInfo:=False;
        end;
        Include(PropertiesModified,opBitmap);
        if AlphaChannel<>nil then Include(PropertiesModified,opAlphaBitmap);
      except
        FreeAndNil(LocalBitmap);
        raise;
      end;
    end
    else if MessageDlgStr(rsErrorRunningImageAnalyzer,mtError,[rsDownload,rsCancel])=1 then ExecuteFile('http://meesoft.logicnet.dk');
  finally
    Screen.Cursor:=crDefault;
    DeleteFile(FileName);
  end;
end;

procedure TPropertyEditorForm.ExportBitmapButtonClick(Sender: TObject);
var
  FileName : string;
begin
  FileName:=MainForm.PicturePath;
  if SaveFileDialog(FileName,BitmapLoaders.GetSaveFilter) then
  try
    Screen.Cursor:=crHourGlass;
    if (AlphaChannel<>nil) and PNGLoader.Default.CanSave(ExtractFileExtNoDotUpper(FileName)) then
    begin
      if LocalAlphaChannel<>nil then PNGLoader.Default.AlphaChannel:=LocalAlphaChannel
      else PNGLoader.Default.AlphaChannel:=AlphaChannel;
    end;
    try
      if Assigned(LocalBitmap) then LocalBitmap.SaveToFile(FileName)
      else Bitmap.SaveToFile(FileName);
    finally
      PNGLoader.Default.AlphaChannel:=nil;
    end;
  finally
    Screen.Cursor:=crDefault;
  end;
end;

procedure TPropertyEditorForm.ExportMetafileButtonClick(Sender: TObject);
var
  FileName : string;
begin
  FileName:=MainForm.PicturePath;
  if SaveFileDialog(FileName,WMFLoader.Default.GetSaveFilter) then
  try
    Screen.Cursor:=crHourGlass;
    Metafile.Enhanced:=ExtractFileExtNoDotUpper(FileName)='EMF';
    Metafile.SaveToFile(FileName);
  finally
    Metafile.Enhanced:=True;
    Screen.Cursor:=crDefault;
  end;
end;

procedure TPropertyEditorForm.NameEditChange(Sender: TObject);
begin
  Include(PropertiesModified,opName);
end;

procedure TPropertyEditorForm.TextEditChange(Sender: TObject);
begin
  Include(PropertiesModified,opText);
end;

procedure TPropertyEditorForm.TextXAlignBoxChange(Sender: TObject);
begin
  Include(PropertiesModified,opTextXAlign);
end;

procedure TPropertyEditorForm.TextYAlignBoxChange(Sender: TObject);
begin
  Include(PropertiesModified,opTextYAlign);
end;

procedure TPropertyEditorForm.PositionChangeValue(Sender: TObject);
begin
  Include(PropertiesModified,opPosition);
end;

procedure TPropertyEditorForm.LineWidthEditChangeValue(Sender: TObject);
begin
  Include(PropertiesModified,opLineWidth);
end;

procedure TPropertyEditorForm.LineStartBoxChange(Sender: TObject);
begin
  Include(PropertiesModified,opLineStart);
end;

procedure TPropertyEditorForm.LineEndBoxChange(Sender: TObject);
begin
  Include(PropertiesModified,opLineEnd);
end;

procedure TPropertyEditorForm.HalftoneCheckBoxClick(Sender: TObject);
begin
  Include(PropertiesModified,opHalftoneStretch);
end;

procedure TPropertyEditorForm.LayoutBoxChange(Sender: TObject);
begin
  Include(PropertiesModified,opRectangleType);
end;

procedure TPropertyEditorForm.EditLinksButtonClick(Sender: TObject);
begin
  with TLinkEditorForm.Create(nil,Handle) do
  try
    List:=Copy(Links);
    Obj:=SingleObject;
    if ShowModal=mrOk then
    begin
      Links:=Copy(List);
      Include(PropertiesModified,opCustomLinks);
      PanelLinks.Caption:=Format(rsDLinkPointsDefined,[Length(Links)]);
    end;
  finally
    Free;
  end;
end;

procedure TPropertyEditorForm.ClearLinksButtonClick(Sender: TObject);
begin
  Links:=nil;
  Include(PropertiesModified,opCustomLinks);
  PanelLinks.Caption:=Format(rsDLinkPointsDefined,[Length(Links)]);
end;

procedure TPropertyEditorForm.AngleEditChangeValue(Sender: TObject);
begin
  Include(PropertiesModified,opAngle);
end;

procedure TPropertyEditorForm.LineStyleBoxChange(Sender: TObject);
begin
  Include(PropertiesModified,opLineStyle);
end;

procedure TPropertyEditorForm.InnerBoundsBoxClick(Sender: TObject);
begin
  Include(PropertiesModified,opBoundsOptions);
end;

procedure TPropertyEditorForm.MarginEditChangeValue(Sender: TObject);
begin
  Include(PropertiesModified,opMargin);
end;

procedure TPropertyEditorForm.AnchorBoxClick(Sender: TObject);
begin
  Include(PropertiesModified,opAnchors);
  if (Sender as TCheckBox).Checked then
    if (Sender=LeftAnchorBox) or (Sender=TopAnchorBox) or (Sender=RightAnchorBox) or (Sender=BottomAnchorBox) then
    begin
      HorzScaleAnchorBox.Checked:=False;
      VertScaleAnchorBox.Checked:=False;
    end
    else if (Sender=HorzScaleAnchorBox) or (Sender=VertScaleAnchorBox) then
    begin
      LeftAnchorBox.Checked:=False;
      TopAnchorBox.Checked:=False;
      RightAnchorBox.Checked:=False;
      BottomAnchorBox.Checked:=False;
    end;
end;

procedure TPropertyEditorForm.CornerRadiusEditChangeValue(Sender: TObject);
begin
  Include(PropertiesModified,opCornerRadius);
end;

procedure TPropertyEditorForm.CurveTypeBoxChange(Sender: TObject);
begin
  Include(PropertiesModified,opCurveType);
end;

procedure TPropertyEditorForm.AlphaValueEditChangeValue(Sender: TObject);
begin
  Include(PropertiesModified,opAlphaValue);
end;

procedure TPropertyEditorForm.ColorKeyButtonClick(Sender: TObject);
var
  ColorKey : TColor;
  Image : TLinearBitmap;
begin
  if LocalBitmap<>nil then Image:=LocalBitmap
  else Image:=Bitmap;
  ColorKey:=Image.PixelColor[0,0];
  if ShowColorDialog(ColorKey) then
  begin
    if Image.PixelFormat=pf8bit then ColorKey:=BestColorMatch(ColorKey,Image.Palette^);
    FreeAndNil(LocalAlphaChannel);
    LocalAlphaChannel:=CreateAlphaChannelFromColorKey(Image,ColorKey);
    Include(PropertiesModified,opAlphaBitmap);
  end;
end;

end.

