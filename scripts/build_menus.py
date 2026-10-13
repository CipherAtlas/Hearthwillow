"""Author the saved native starter, Settings, Sound, guide and keybinding controls."""
from pathlib import Path
import json
q=lambda s:json.dumps(s,ensure_ascii=False)
rows=['[gd_scene load_steps=10 format=3]','[ext_resource type="Script" path="res://scenes/village_menus.gd" id="1"]','[ext_resource type="FontFile" path="res://assets/fonts/Outfit.tres" id="2"]', '''[sub_resource type="FontVariation" id="Sans"]
base_font = ExtResource("2")
variation_opentype = {2003265652:400.0}
[sub_resource type="SystemFont" id="Serif"]
font_names = PackedStringArray("Georgia", "Times New Roman")
[sub_resource type="StyleBoxFlat" id="Panel"]
bg_color = Color(0.12549, 0.239216, 0.203922, 0.92157)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.9137,0.8627,0.7373,0.2588)
corner_radius_top_left = 14
corner_radius_top_right = 14
corner_radius_bottom_left = 14
corner_radius_bottom_right = 14
content_margin_left = 22.0
content_margin_right = 22.0
content_margin_top = 22.0
content_margin_bottom = 22.0
shadow_color = Color(0.0353,0.149,0.1137,0.25)
shadow_size = 20
shadow_offset = Vector2(0,12)
[sub_resource type="StyleBoxFlat" id="Button"]
bg_color = Color(0.08235,0.21569,0.18039,0.87843)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.8667,0.8549,0.7569,0.23)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
content_margin_left = 12.0
content_margin_right = 12.0
content_margin_top = 10.0
content_margin_bottom = 10.0
[sub_resource type="StyleBoxFlat" id="Hover"]
bg_color = Color(0.192,0.326,0.251,0.95)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.945,0.874,0.725,0.8)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
content_margin_left = 12.0
content_margin_right = 12.0
content_margin_top = 10.0
content_margin_bottom = 10.0
[sub_resource type="Theme" id="Theme"]
default_font = SubResource("Sans")
default_font_size = 14
Label/colors/font_color = Color(0.965,0.933,0.851,1)
Button/colors/font_color = Color(0.965,0.933,0.851,1)
Button/styles/normal = SubResource("Button")
Button/styles/hover = SubResource("Hover")
Button/styles/focus = SubResource("Hover")
Button/styles/pressed = SubResource("Hover")
OptionButton/styles/normal = SubResource("Button")
OptionButton/styles/hover = SubResource("Hover")
OptionButton/colors/font_color = Color(0.965,0.933,0.851,1)
PanelContainer/styles/panel = SubResource("Panel")
[sub_resource type="Gradient" id="ShadeGradient"]
offsets = PackedFloat32Array(0,0.48,0.8,1)
colors = PackedColorArray(0.06275,0.15294,0.11373,0.86,0.06275,0.15294,0.11373,0.41,0.06275,0.15294,0.11373,0.03,0.06275,0.15294,0.11373,0.03)
[sub_resource type="GradientTexture2D" id="ShadeTexture"]
gradient = SubResource("ShadeGradient")
fill_from = Vector2(0,0)
fill_to = Vector2(1,0)
''']
def node(name,typ,parent=None,props=None):
 head=f'[node name={q(name)} type={q(typ)}'+(f' parent={q(parent)}' if parent is not None else '')+']'
 rows.append(head)
 rows.extend(k+' = '+v for k,v in (props or {}).items())
 return (parent+'/'+name if parent and parent!='.' else name) if parent is not None else '.'
def full():return dict(layout_mode='0',anchors_preset='15',anchor_right='1.0',anchor_bottom='1.0',grow_horizontal='2',grow_vertical='2')
def label(name,parent,text,size=14,serif=False,props=None):
 p={'layout_mode':'2','text':q(text),'theme_override_font_sizes/font_size':str(size)}
 if serif:p['theme_override_fonts/font']='SubResource("Serif")'
 p.update(props or {});return node(name,'Label',parent,p)
def button(name,parent,text):return node(name,'Button',parent,{'layout_mode':'2','custom_minimum_size':'Vector2(0,44)','text':q(text),'mouse_default_cursor_shape':'2'})
connections=[]
def connect(path,signal,method,binds=None):connections.append(f'[connection signal={q(signal)} from={q(path)} to="." method={q(method)}'+(' binds= ['+', '.join(q(b) if isinstance(b,str) else str(b) for b in binds)+']' if binds else '')+']')
node('Menus','Control',props={**full(),'mouse_filter':'2','theme':'SubResource("Theme")','script':'ExtResource("1")'})
node('Dim','ColorRect','.',{**full(),'visible':'false','color':'Color(0.075,0.169,0.137,0.2)'})
node('Starter','Control','.',full())
node('Shade','TextureRect','Starter',{**full(),'texture':'SubResource("ShadeTexture")','mouse_filter':'2','expand_mode':'1'})
node('Content','VBoxContainer','Starter',{'layout_mode':'0','anchor_left':'0.07','anchor_top':'0.5','anchor_right':'0.07','anchor_bottom':'0.5','offset_top':'-200.0','offset_right':'660.0','offset_bottom':'220.0','theme_override_constants/separation':'36'})
label('Title','Starter/Content','Hearthwillow',94,True)
node('Menu','VBoxContainer','Starter/Content',{'layout_mode':'2','size_flags_horizontal':'0','custom_minimum_size':'Vector2(340,0)','theme_override_constants/separation':'12'})
for name,text in [('Enter','Enter Hearthwillow'),('Language','Language                         English'),('Settings','Settings')]:
 p=button(name,'Starter/Content/Menu',text);connect(p,'pressed','enter_game' if name=='Enter' else 'open_language' if name=='Language' else 'open_settings')
label('Hint','Starter','W A S D   Move       Mouse to look       E   Interact',13,props={'layout_mode':'0','anchor_left':'0.07','anchor_top':'1.0','anchor_right':'0.9','anchor_bottom':'1.0','offset_top':'-52.0','offset_bottom':'-24.0'})
node('Settings','PanelContainer','.',{'visible':'false','layout_mode':'0','anchor_left':'1.0','anchor_right':'1.0','offset_left':'-440.0','offset_top':'20.0','offset_right':'-20.0','offset_bottom':'860.0'})
node('Content','VBoxContainer','Settings',{'layout_mode':'2','theme_override_constants/separation':'16'})
node('Heading','HBoxContainer','Settings/Content',{'layout_mode':'2'})
label('Title','Settings/Content/Heading','Settings',28,True,{'size_flags_horizontal':'3'})
p=button('Close','Settings/Content/Heading','×');connect(p,'pressed','close_menu')
node('Tabs','HBoxContainer','Settings/Content',{'layout_mode':'2','theme_override_constants/separation':'5'})
for i,name in enumerate(['Experience','Sound','Controls']):
 p=button(name,'Settings/Content/Tabs',name);rows.append('size_flags_horizontal = 3');connect(p,'pressed','set_tab',[i])
node('Scroll','ScrollContainer','Settings/Content',{'layout_mode':'2','size_flags_vertical':'3','horizontal_scroll_mode':'0'})
node('Pages','VBoxContainer','Settings/Content/Scroll',{'layout_mode':'2','size_flags_horizontal':'3','theme_override_constants/separation':'18'})
for section in ['Experience','Sound','Controls']:
 node(section,'VBoxContainer','Settings/Content/Scroll/Pages',{'layout_mode':'2','size_flags_horizontal':'3','theme_override_constants/separation':'16','visible':'true' if section=='Experience' else 'false'})
base='Settings/Content/Scroll/Pages/'
def options(name,section,title,items,method):
 parent=base+section;label(name+'Label',parent,title)
 p=node(name,'OptionButton',parent,{'layout_mode':'2','custom_minimum_size':'Vector2(0,44)','item_count':str(len(items)),**{f'popup/item_{i}/text':q(x) for i,x in enumerate(items)},**{f'popup/item_{i}/id':str(i) for i in range(len(items))}})
 connect(p,'item_selected',method)
options('Weather','Experience','Time & weather',['Follow local time','Golden hour','Blue hour','Night','Rain'],'set_weather')
options('Graphics','Experience','Graphics',['Detailed','Low power','Automatic'],'set_graphics')
options('Language','Experience','Language',['English','日本語'],'set_language')
p=node('SkipGuide','CheckBox',base+'Experience',{'layout_mode':'2','text':q("Don't show tutorial")});connect(p,'toggled','set_skip_guide')
p=button('Guide',base+'Experience','Read the village guide');connect(p,'pressed','open_guide')
label('Performance',base+'Experience','',13)
label('Balance',base+'Sound','Sound balance',18)
p=button('Reset',base+'Sound','Reset sound');connect(p,'pressed','reset_sound')
p=button('Toggle',base+'Sound','Turn sound on');connect(p,'pressed','toggle_audio')
options('Soundtrack','Sound','Soundtrack',['Follow the scenery','Village paths','Pond & tea garden','Quiet cottage','By the hearth'],'set_soundtrack')
label('Credit',base+'Sound','Recorded music by Holizna.',13)
for name,title,value in [('Music','Music',.15),('World','World',.54),('Effects','Effects',.75),('Rain','Rain',.12),('Fire','Fire',.35),('Master','Volume',.5)]:
 parent=node(name+'Row','HBoxContainer',base+'Sound',{'layout_mode':'2'})
 label('Label',parent,title,14,props={'size_flags_horizontal':'3'})
 label('Value',parent,str(round(value*100))+'%',14)
 p=node(name,'HSlider',base+'Sound',{'layout_mode':'2','custom_minimum_size':'Vector2(0,28)','max_value':'1.0','step':'0.01','value':str(value),'focus_mode':'2'});connect(p,'value_changed','set_mix',[name.lower()])
label('SensitivityLabel',base+'Controls','Mouse sensitivity   100%')
p=node('Sensitivity','HSlider',base+'Controls',{'layout_mode':'2','custom_minimum_size':'Vector2(0,28)','min_value':'0.25','max_value':'2.0','step':'0.05','value':'1.0'});connect(p,'value_changed','set_sensitivity')
label('KeysTitle',base+'Controls','Keybindings',18)
label('KeyHelp',base+'Controls','Select a key, then press its replacement. Escape cancels.',13,props={'autowrap_mode':'3'})
p=button('ResetKeys',base+'Controls','Reset keys');connect(p,'pressed','reset_keys')
node('Bindings','VBoxContainer',base+'Controls',{'layout_mode':'2','theme_override_constants/separation':'8'})
actions=[('move_forward','Move forward'),('move_left','Move left'),('move_back','Move back'),('move_right','Move right'),('dash','Hold to run / canter'),('jump','Jump / brake'),('glide','Glide'),('unstuck','Recover'),('interact','Interact'),('talk','Talk / feed'),('companion','Walk with a resident'),('bread','Crumbs / forage'),('puppy_follow','Walk with a dog'),('puppy_home','Dog home'),('puppy_sit','Dog sit'),('puppy_dance','Dog dance'),('puppy_spin','Dog spin'),('puppy_bow','Dog bow'),('puppy_wave','Dog wave'),('puppy_roll','Dog roll'),('toggle_map','Map'),('toggle_sound','Sound'),('toggle_settings','Settings')]
for action,title in actions:
 parent=node(action,'HBoxContainer',base+'Controls/Bindings',{'layout_mode':'2'})
 label('Label',parent,title,14,props={'size_flags_horizontal':'3'})
 p=button('Key',parent,'');rows.append('custom_minimum_size = Vector2(74,44)');connect(p,'pressed','begin_rebind',[action])
label('Status',base+'Controls','',13,props={'autowrap_mode':'3'})
label('Footer','Settings/Content','Changes save on this device.',13)
p=button('Back','Settings/Content','Esc   Back   ⌫');connect(p,'pressed','close_menu')
for name,title,text in [('Guide','Village guide','Move\nW A S D to move. Click the view, then move your mouse to look. E is for nearby actions.\n\nActivities\nM opens the village map.\n\nConversations\nF talks to a nearby villager. C invites a walking companion. E pets an animal or mounts a horse.\n\nSettings\nComma opens Settings. O opens Sound. Escape leaves menus.'),('Language','Language','')]:
 node(name,'PanelContainer','.',{'visible':'false','layout_mode':'0','anchor_left':'0.5','anchor_right':'0.5','anchor_top':'0.5','anchor_bottom':'0.5','offset_left':'-250.0','offset_right':'250.0','offset_top':'-260.0','offset_bottom':'260.0'})
 node('Content','VBoxContainer',name,{'layout_mode':'2','theme_override_constants/separation':'18'})
 label('Title',name+'/Content',title,28,True)
 if text:label('Text',name+'/Content',text,16,props={'autowrap_mode':'3','size_flags_vertical':'3'})
 if name=='Language':
  for i,title in enumerate(['English','日本語']):
   p=button('Choice'+str(i),name+'/Content',title);connect(p,'pressed','choose_language',[i])
 p=button('Back',name+'/Content','E   Continue' if name=='Guide' else 'Esc   Back');connect(p,'pressed','close_menu')
rows.extend(connections)
Path('scenes/menus.tscn').write_text('\n\n'.join(rows)+'\n')
