# ============================================================
#  CookieGuard - Ui.Theme.ps1
#  Один набор стилей на все окна программы.
#
#  Зачем отдельный файл. Окон у программы три: главное, окно
#  проверки файлов и диалоги. Если бы каждое несло свою копию
#  стилей, они разъехались бы на второй правке — а разъехавшийся
#  интерфейс читается как собранный на коленке, и доверия к
#  тому, что он показывает, не прибавляет.
#
#  Откуда взят вид. Раскладка — как в «Параметрах» Windows 11:
#  слева список разделов, справа карточки. Это не подражание
#  ради подражания: человек уже знает, где искать, и не тратит
#  внимание на изучение нашего интерфейса вместо чтения находок.
#  Ни одного стандартного системного окна не используется —
#  MessageBox и InputBox выглядят здесь чужими.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml -ErrorAction SilentlyContinue

# Шрифт заголовков: на Windows 11 есть Segoe UI Variable, на 10 — нет.
# WPF сам возьмёт первый существующий из списка.
$script:CgFont     = 'Segoe UI Variable Text, Segoe UI'
$script:CgFontHead = 'Segoe UI Variable Display, Segoe UI'

$script:CgThemeXaml = @'
    <!-- ============ цвета ============ -->
    <SolidColorBrush x:Key="WinBg"       Color="#101217"/>
    <SolidColorBrush x:Key="NavBg"       Color="#15181E"/>
    <SolidColorBrush x:Key="ContentBg"   Color="#101217"/>
    <SolidColorBrush x:Key="CardBg"      Color="#191D24"/>
    <SolidColorBrush x:Key="CardBgAlt"   Color="#1E222A"/>
    <SolidColorBrush x:Key="ControlBg"   Color="#232832"/>
    <SolidColorBrush x:Key="ControlBgHi" Color="#2B313C"/>
    <SolidColorBrush x:Key="Line"        Color="#262B34"/>
    <SolidColorBrush x:Key="StrongLine"  Color="#39404D"/>
    <SolidColorBrush x:Key="Text"        Color="#ECEFF4"/>
    <SolidColorBrush x:Key="TextDim"     Color="#A9B2C0"/>
    <SolidColorBrush x:Key="Muted"       Color="#7C8694"/>
    <SolidColorBrush x:Key="Accent"      Color="#3B9EFF"/>
    <SolidColorBrush x:Key="AccentHi"    Color="#5BB0FF"/>
    <SolidColorBrush x:Key="AccentDim"   Color="#1E3A5C"/>
    <SolidColorBrush x:Key="Crit"        Color="#FF5E5E"/>
    <SolidColorBrush x:Key="CritDim"     Color="#3A1E22"/>
    <SolidColorBrush x:Key="Warn"        Color="#FFB340"/>
    <SolidColorBrush x:Key="WarnDim"     Color="#3A2E18"/>
    <SolidColorBrush x:Key="Ok"          Color="#4ADE80"/>
    <SolidColorBrush x:Key="OkDim"       Color="#16301F"/>
    <SolidColorBrush x:Key="Note"        Color="#7CC4FF"/>

    <!-- ============ базовая типографика ============ -->
    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="13"/>
      <Setter Property="TextOptions.TextFormattingMode" Value="Ideal"/>
    </Style>

    <Style x:Key="H1" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Display, Segoe UI"/>
      <Setter Property="FontSize"   Value="28"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="H2" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Display, Segoe UI"/>
      <Setter Property="FontSize"   Value="16"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Sub" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="12"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>
    <Style x:Key="Glyph" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontSize"   Value="16"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="VerticalAlignment"   Value="Center"/>
    </Style>

    <!-- ============ полосы прокрутки ============ -->
    <Style x:Key="ScrollThumb" TargetType="Thumb">
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Thumb">
            <Border x:Name="t" Background="#4A525F" CornerRadius="3" Margin="3,0"/>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="t" Property="Background" Value="#68707E"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ScrollBar">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Width" Value="12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                </Track.DecreaseRepeatButton>
                <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}"/></Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                </Track.IncreaseRepeatButton>
              </Track>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Orientation" Value="Horizontal">
                <Setter Property="Height" Value="12"/>
                <Setter TargetName="PART_Track" Property="IsDirectionReversed" Value="False"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ кнопки ============ -->
    <Style TargetType="Button">
      <Setter Property="Background"   Value="{StaticResource ControlBg}"/>
      <Setter Property="Foreground"   Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush"  Value="{StaticResource StrongLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding"      Value="14,7"/>
      <Setter Property="Margin"       Value="0,0,8,0"/>
      <Setter Property="FontFamily"   Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"     Value="13"/>
      <Setter Property="Cursor"       Value="Hand"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="{StaticResource ControlBgHi}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.75"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background"  Value="{StaticResource Accent}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground"  Value="#07121D"/>
      <Setter Property="FontWeight"  Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="{StaticResource AccentHi}"/>
                <Setter TargetName="b" Property="BorderBrush" Value="{StaticResource AccentHi}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.8"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Danger" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background"  Value="#4A1F24"/>
      <Setter Property="BorderBrush" Value="#7A3038"/>
      <Setter Property="Foreground"  Value="#FFB4B4"/>
    </Style>

    <Style x:Key="Good" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background"  Value="#17301F"/>
      <Setter Property="BorderBrush" Value="#2F5E3E"/>
      <Setter Property="Foreground"  Value="#9BE8B6"/>
    </Style>

    <!-- кнопка без рамки: панель окна, мелкие действия -->
    <Style x:Key="Ghost" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background"  Value="Transparent"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="Foreground"  Value="{StaticResource TextDim}"/>
    </Style>

    <!-- кнопки заголовка окна -->
    <Style x:Key="CaptionBtn" TargetType="Button">
      <Setter Property="Width" Value="46"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Margin" Value="0"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="Cursor" Value="Arrow"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#262B34"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="CaptionClose" TargetType="Button" BasedOn="{StaticResource CaptionBtn}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#C42B1C"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ список разделов слева ============ -->
    <Style x:Key="NavList" TargetType="ListBox">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
      <Setter Property="Padding" Value="0"/>
    </Style>
    <Style x:Key="NavItem" TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="6,1,6,1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid>
              <Border x:Name="bg" Background="Transparent" CornerRadius="5" Height="38"/>
              <Border x:Name="bar" Width="3" Height="18" CornerRadius="2" Background="{StaticResource Accent}"
                      HorizontalAlignment="Left" Margin="1,0,0,0" Opacity="0"/>
              <ContentPresenter VerticalAlignment="Center" Margin="14,0,10,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Background" Value="#1E2129"/></Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="bg"  Property="Background" Value="#252A33"/>
                <Setter TargetName="bar" Property="Opacity" Value="1"/>
                <Setter Property="Foreground" Value="{StaticResource Text}"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ карточка ============ -->
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background"      Value="{StaticResource CardBg}"/>
      <Setter Property="BorderBrush"     Value="{StaticResource Line}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius"    Value="8"/>
      <Setter Property="Padding"         Value="16,14"/>
      <Setter Property="Margin"          Value="0,0,0,8"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
    </Style>
    <Style x:Key="CardRow" TargetType="Border" BasedOn="{StaticResource Card}">
      <Setter Property="Padding" Value="16,12"/>
    </Style>
    <Style x:Key="Tile" TargetType="Border" BasedOn="{StaticResource Card}">
      <Setter Property="Margin"   Value="0,0,8,8"/>
      <Setter Property="MinWidth" Value="196"/>
      <Setter Property="Padding"  Value="16,14"/>
    </Style>

    <!-- ============ поля ввода ============ -->
    <Style TargetType="TextBox">
      <Setter Property="Background"  Value="{StaticResource ControlBg}"/>
      <Setter Property="Foreground"  Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush" Value="{StaticResource StrongLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontFamily"  Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"    Value="13"/>
      <Setter Property="Padding"     Value="10,7"/>
      <Setter Property="CaretBrush"  Value="{StaticResource Text}"/>
      <Setter Property="SelectionBrush" Value="{StaticResource Accent}"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"
                            VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4A5260"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Mono" TargetType="TextBox" BasedOn="{StaticResource {x:Type TextBox}}">
      <Setter Property="FontFamily" Value="Cascadia Mono, Consolas"/>
      <Setter Property="FontSize"   Value="12"/>
      <Setter Property="Background" Value="#0D1014"/>
      <Setter Property="Foreground" Value="#C2CBD6"/>
      <Setter Property="Padding"    Value="12,10"/>
      <Setter Property="IsReadOnly" Value="True"/>
      <Setter Property="VerticalContentAlignment" Value="Top"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="PasswordBox">
      <Setter Property="Background"  Value="{StaticResource ControlBg}"/>
      <Setter Property="Foreground"  Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush" Value="{StaticResource StrongLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontFamily"  Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"    Value="13"/>
      <Setter Property="Padding"     Value="10,7"/>
      <Setter Property="CaretBrush"  Value="{StaticResource Text}"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="PasswordBox">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"
                            VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ флажок и переключатель ============ -->
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="13"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Margin"     Value="0,0,14,0"/>
      <Setter Property="Cursor"     Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <StackPanel Orientation="Horizontal" Background="Transparent">
              <Border x:Name="box" Width="20" Height="20" CornerRadius="4" VerticalAlignment="Center"
                      Background="{StaticResource ControlBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1">
                <TextBlock x:Name="gl" Text="&#xE73E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11"
                           Foreground="#07121D" HorizontalAlignment="Center" VerticalAlignment="Center" Opacity="0"/>
              </Border>
              <ContentPresenter Margin="9,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="box" Property="Background"  Value="{StaticResource Accent}"/>
                <Setter TargetName="box" Property="BorderBrush" Value="{StaticResource Accent}"/>
                <Setter TargetName="gl"  Property="Opacity" Value="1"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="box" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- переключатель «включено / выключено» как в Параметрах -->
    <Style x:Key="Toggle" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="track" Width="42" Height="22" CornerRadius="11" Background="{StaticResource ControlBg}"
                    BorderBrush="{StaticResource StrongLine}" BorderThickness="1" Padding="0">
              <Ellipse x:Name="knob" Width="12" Height="12" Fill="{StaticResource TextDim}"
                       HorizontalAlignment="Left" VerticalAlignment="Center" Margin="4,0,0,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="track" Property="Background"  Value="{StaticResource Accent}"/>
                <Setter TargetName="track" Property="BorderBrush" Value="{StaticResource Accent}"/>
                <Setter TargetName="knob"  Property="Fill" Value="#07121D"/>
                <Setter TargetName="knob"  Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="knob"  Property="Margin" Value="0,0,4,0"/>
                <Setter TargetName="knob"  Property="Width"  Value="14"/>
                <Setter TargetName="knob"  Property="Height" Value="14"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="track" Property="BorderBrush" Value="{StaticResource AccentHi}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ выпадающий список ============ -->
    <Style x:Key="CmbToggle" TargetType="ToggleButton">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <Border x:Name="b" Background="{StaticResource ControlBg}" BorderBrush="{StaticResource StrongLine}"
                    BorderThickness="1" CornerRadius="6">
              <TextBlock Text="&#xE70D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10"
                         Foreground="{StaticResource TextDim}" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,11,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="{StaticResource ControlBgHi}"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="13"/>
      <Setter Property="Height"     Value="34"/>
      <Setter Property="Cursor"     Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton Style="{StaticResource CmbToggle}" Focusable="False" ClickMode="Press"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"/>
              <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                Margin="12,0,32,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
              <Popup x:Name="PART_Popup" Placement="Bottom" AllowsTransparency="True" Focusable="False"
                     IsOpen="{TemplateBinding IsDropDownOpen}" PopupAnimation="Fade">
                <Border Background="#1E222A" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" CornerRadius="7"
                        MinWidth="{TemplateBinding ActualWidth}" Margin="0,4,0,0" Padding="3">
                  <Border.Effect><DropShadowEffect BlurRadius="18" ShadowDepth="3" Opacity="0.5" Color="#000000"/></Border.Effect>
                  <ScrollViewer MaxHeight="300"><StackPanel IsItemsHost="True"/></ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="13"/>
      <Setter Property="Padding"    Value="10,7"/>
      <Setter Property="Cursor"     Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="b" Background="Transparent" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2B313C"/></Trigger>
              <Trigger Property="IsSelected" Value="True"><Setter TargetName="b" Property="Background" Value="{StaticResource AccentDim}"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ таблица ============ -->
    <Style TargetType="DataGrid">
      <Setter Property="Background"      Value="Transparent"/>
      <Setter Property="Foreground"      Value="{StaticResource Text}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="RowBackground"            Value="Transparent"/>
      <Setter Property="AlternatingRowBackground" Value="#14171C"/>
      <Setter Property="GridLinesVisibility" Value="None"/>
      <Setter Property="HeadersVisibility"   Value="Column"/>
      <Setter Property="AutoGenerateColumns" Value="False"/>
      <Setter Property="IsReadOnly"          Value="True"/>
      <Setter Property="SelectionMode"       Value="Single"/>
      <Setter Property="CanUserAddRows"      Value="False"/>
      <Setter Property="EnableRowVirtualization" Value="True"/>
      <Setter Property="RowHeight"   Value="34"/>
      <Setter Property="FontFamily"  Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"    Value="12"/>
      <Setter Property="VerticalGridLinesBrush"   Value="Transparent"/>
      <Setter Property="HorizontalGridLinesBrush" Value="Transparent"/>
    </Style>
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background"  Value="Transparent"/>
      <Setter Property="Foreground"  Value="{StaticResource Muted}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="Padding"     Value="12,9"/>
      <Setter Property="FontSize"    Value="11"/>
      <Setter Property="FontWeight"  Value="SemiBold"/>
      <Setter Property="FontFamily"  Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
    </Style>
    <Style TargetType="DataGridCell">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="12,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="DataGridCell">
            <Border Background="Transparent" Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="DataGridRow">
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Style.Triggers>
        <DataTrigger Binding="{Binding Severity}" Value="CRIT">
          <Setter Property="Foreground" Value="{StaticResource Crit}"/>
          <Setter Property="FontWeight" Value="SemiBold"/>
        </DataTrigger>
        <DataTrigger Binding="{Binding Severity}" Value="WARN"><Setter Property="Foreground" Value="{StaticResource Warn}"/></DataTrigger>
        <DataTrigger Binding="{Binding Severity}" Value="NOTE"><Setter Property="Foreground" Value="{StaticResource Note}"/></DataTrigger>
        <DataTrigger Binding="{Binding Severity}" Value="OK"><Setter Property="Foreground" Value="{StaticResource Ok}"/></DataTrigger>
        <DataTrigger Binding="{Binding Severity}" Value="INFO"><Setter Property="Foreground" Value="{StaticResource Muted}"/></DataTrigger>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#1C2029"/></Trigger>
        <Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="{StaticResource AccentDim}"/></Trigger>
      </Style.Triggers>
    </Style>

    <!-- ============ меню по правой кнопке ============ -->
    <Style TargetType="ContextMenu">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="HasDropShadow" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ContextMenu">
            <Border Background="#1E222A" BorderBrush="{StaticResource StrongLine}" BorderThickness="1"
                    CornerRadius="8" Padding="4" Margin="8">
              <Border.Effect><DropShadowEffect BlurRadius="20" ShadowDepth="4" Opacity="0.55" Color="#000000"/></Border.Effect>
              <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="MenuItem">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="13"/>
      <Setter Property="Cursor"     Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="MenuItem">
            <Border x:Name="b" Background="Transparent" CornerRadius="5" Padding="10,7" MinWidth="200">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="22"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="{TemplateBinding Tag}" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                           FontSize="13" Foreground="{StaticResource TextDim}" VerticalAlignment="Center"/>
                <ContentPresenter Grid.Column="1" ContentSource="Header" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="2" Text="{TemplateBinding InputGestureText}" Foreground="{StaticResource Muted}"
                           FontSize="11" VerticalAlignment="Center" Margin="18,0,0,0"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="b" Property="Background" Value="#2B313C"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.35"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Separator">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Separator">
            <Border Height="1" Background="{StaticResource Line}" Margin="8,4"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ подсказка ============ -->
    <Style TargetType="ToolTip">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="12"/>
      <Setter Property="MaxWidth"   Value="380"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToolTip">
            <Border Background="#1E222A" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" CornerRadius="6" Padding="11,8" Margin="6">
              <Border.Effect><DropShadowEffect BlurRadius="14" ShadowDepth="2" Opacity="0.5" Color="#000000"/></Border.Effect>
              <ContentPresenter/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============ полоса хода работы ============ -->
    <Style TargetType="ProgressBar">
      <Setter Property="Background"  Value="#232832"/>
      <Setter Property="Foreground"  Value="{StaticResource Accent}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Height" Value="4"/>
    </Style>

    <Style TargetType="GridSplitter">
      <Setter Property="Background" Value="Transparent"/>
    </Style>
'@

# ------------------------------------------------------------
#  Сборка окна из разметки
#
#  Разметка каждого окна содержит метку <!--THEME-->, вместо
#  которой подставляются общие стили. Replace, а не -replace:
#  в стилях есть знаки, которые регулярное выражение съело бы.
# ------------------------------------------------------------
function New-CgWindow {
    param([string]$Xaml)
    $full = $Xaml.Replace('<!--THEME-->', $script:CgThemeXaml)
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$full)
    return [Windows.Markup.XamlReader]::Load($reader)
}

function Get-CgUiMap {
    param($Window, [string[]]$Names)
    $m = @{}
    foreach ($n in $Names) { $m[$n] = $Window.FindName($n) }
    return $m
}

# Перетаскивание окна за собственный заголовок: своя рамка —
# значит, и это теперь наша забота.
function Add-CgWindowDrag {
    param($Window, $DragArea, $MaxButton = $null)
    $DragArea.Add_MouseLeftButtonDown({
        param($s, $e)
        if ($e.ClickCount -eq 2) {
            if ($Window.ResizeMode -ne 'NoResize') {
                if ($Window.WindowState -eq 'Maximized') { $Window.WindowState = 'Normal' } else { $Window.WindowState = 'Maximized' }
            }
            return
        }
        try { $Window.DragMove() } catch { }
    }.GetNewClosure())
}
