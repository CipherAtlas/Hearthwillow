"""One-time saved scene authoring. Refuses to replace the human-editable scene."""
from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]
if (root/'scenes/quiet_places.tscn').exists():
    raise SystemExit('quiet_places.tscn exists; edit the saved scene instead.')

def quoted(v): return json.dumps(v,ensure_ascii=False)
class Scene:
    def __init__(self): self.resources=[]; self.nodes=[]; self.connections=[]
    def ext(self,typ,path,key): self.resources.append(f'[ext_resource type="{typ}" path="{path}" id="{key}"]'); return f'ExtResource("{key}")'
    def sub(self,typ,key,props): self.resources.append(f'[sub_resource type="{typ}" id="{key}"]\n'+''.join(f'{k} = {v}\n' for k,v in props.items())); return f'SubResource("{key}")'
    def node(self,name,typ,parent=None,props=None,instance=None):
        head=f'[node name="{name}"'+(f' type="{typ}"' if typ else '')+(f' parent="{parent}"' if parent is not None else '')+(f' instance={instance}' if instance else '')+']\n'
        self.nodes.append(head+''.join(f'{k} = {v}\n' for k,v in (props or {}).items()))
    def connect(self,path,signal,method,to='.',binds=None): self.connections.append(f'[connection signal="{signal}" from="{path}" to="{to}" method="{method}"'+(f' binds={binds}' if binds else '')+']')
    def save(self,path): (root/path).write_text('[gd_scene format=3]\n\n'+'\n\n'.join(self.resources+self.nodes+self.connections)+'\n')

# Paper panels use the site's cream paper, Georgia titles and forest buttons.
(root/'scenes/journal_theme.tres').write_text('''[gd_resource type="Theme" format=3]
[ext_resource type="FontFile" path="res://assets/fonts/Outfit.tres" id="1"]
[sub_resource type="StyleBoxFlat" id="Paper"]
content_margin_left = 26.0
content_margin_top = 26.0
content_margin_right = 26.0
content_margin_bottom = 26.0
bg_color = Color(0.97, 0.95, 0.90, 0.98)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.82, 0.86, 0.78, 0.9)
corner_radius_top_left = 20
corner_radius_top_right = 20
corner_radius_bottom_left = 20
corner_radius_bottom_right = 20
shadow_color = Color(0.06, 0.18, 0.15, 0.22)
shadow_size = 14
[sub_resource type="StyleBoxFlat" id="Entry"]
content_margin_left = 18.0
content_margin_top = 12.0
content_margin_right = 18.0
content_margin_bottom = 12.0
bg_color = Color(1, 0.99, 0.965, 1)
border_width_left = 4
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.78, 0.83, 0.76, 1)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_left = 12
corner_radius_bottom_right = 12
[sub_resource type="StyleBoxFlat" id="Focus"]
content_margin_left = 18.0
content_margin_top = 12.0
content_margin_right = 18.0
content_margin_bottom = 12.0
bg_color = Color(1, 0.99, 0.965, 1)
border_width_left = 4
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.38, 0.52, 0.44, 1)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_left = 12
corner_radius_bottom_right = 12
[resource]
default_font = ExtResource("1")
default_font_size = 14
Label/colors/font_color = Color(0.16, 0.31, 0.26, 1)
PanelContainer/styles/panel = SubResource("Paper")
TextEdit/colors/font_color = Color(0.20, 0.30, 0.26, 1)
TextEdit/colors/caret_color = Color(0.16, 0.31, 0.26, 1)
TextEdit/colors/selection_color = Color(0.45, 0.65, 0.53, 0.3)
TextEdit/styles/normal = SubResource("Entry")
TextEdit/styles/focus = SubResource("Focus")
TextEdit/constants/line_spacing = 7
''')
s=Scene()
behavior=s.ext('Script','res://scenes/quiet_places.gd','behavior')
journal=s.ext('Script','res://scenes/village_journal.gd','journal')
feedback=s.ext('Script','res://scenes/interaction_button.gd','button')
paper=s.ext('Theme','res://scenes/journal_theme.tres','paper')
forest=s.ext('Theme','res://scenes/interaction_theme.tres','forest')
key=s.ext('StyleBox','res://scenes/interaction_keycap.tres','key')
georgia=s.ext('FontFile','res://assets/fonts/Georgia.tres','georgia')
kind=s.ext('PackedScene','res://assets/quiet/kind-note.glb','kind')
quill=s.ext('PackedScene','res://assets/quiet/writing-quill.glb','quill')
page=s.ext('PackedScene','res://assets/quiet/saved-page.glb','page')
orbit=s.ext('Script','res://scenes/breath_orbit.gd','orbit')
ringmat=s.sub('StandardMaterial3D','RingMaterial',{'transparency':'1','shading_mode':'0','albedo_color':'Color(0.65, 0.92, 0.84, 0.22)','cull_mode':'2','no_depth_test':'false'})
ring=s.sub('TorusMesh','Ring',{'inner_radius':'0.94','outer_radius':'1.0','rings':'80','ring_segments':'6','material':ringmat})
s.node('QuietPlaces','Node3D',props={'script':behavior})
s.node('Camera','Camera3D','.',{'fov':'46.0'})
s.node('Ritual','Node3D','.')
s.node('Quill',None,'Ritual',instance=quill)
s.node('Page',None,'Ritual',{'visible':'false'},instance=page)
s.node('Letter','Node3D','.',{'visible':'false'})
s.node('Model',None,'Letter',instance=kind)
s.node('Rings','Node3D','.',{'visible':'false'})
for i in range(3): s.node(f'Ring{i}','MeshInstance3D','Rings',{'mesh':ring,'cast_shadow':'0','scale':'Vector3(1, 0.05, 1)'})
s.node('UI','CanvasLayer','.',{'layer':'4'})

def label(name,parent,text='',props=None):
    s.node(name,'Label',parent,{'layout_mode':'2','text':quoted(text),**(props or {})})
def box(name,parent): s.node(name,'VBoxContainer',parent,{'layout_mode':'2','theme_override_constants/separation':'12'})
def button(name,parent,text,method,action='',binds=None,plain=False):
    s.node(name,'Button',parent,{'layout_mode':'2','custom_minimum_size':'Vector2(0,44)','theme':forest,'script':feedback,'action':quoted(action),'text':quoted(text) if plain else '""'})
    path=parent+'/'+name
    if not plain:
        s.node('Row','HBoxContainer',path,{'layout_mode':'0','anchors_preset':'15','anchor_right':'1.0','anchor_bottom':'1.0','offset_left':'8.0','offset_right':'-8.0','offset_top':'5.0','offset_bottom':'-5.0','mouse_filter':'2','alignment':'1','theme_override_constants/separation':'8'})
        s.node('Key','PanelContainer',path+'/Row',{'layout_mode':'2','mouse_filter':'2','custom_minimum_size':'Vector2(26,26)','size_flags_vertical':'4','theme_override_styles/panel':key,'visible':'true' if action else 'false'})
        label('Text',path+'/Row/Key','',{'horizontal_alignment':'1','vertical_alignment':'1','mouse_filter':'2','theme_override_font_sizes/font_size':'12','theme_override_colors/font_color':'Color(1,0.95,0.82,1)'})
        label('Text',path+'/Row',text,{'vertical_alignment':'1','mouse_filter':'2','theme_override_colors/font_color':'Color(1,0.95,0.82,1)'})
    s.connect(path,'pressed',method,binds=binds)

def panel(name,width,paper_panel=True):
    s.node(name,'PanelContainer','UI',{'visible':'false','offset_left':str(1920-width-28)+'.0','offset_top':'220.0','offset_right':'1892.0','offset_bottom':'230.0','custom_minimum_size':f'Vector2({width},0)','theme':paper if paper_panel else forest})
    box('Content','UI/'+name)

panel('Journal',400)
# The journal scene owns the controls and file dialogs; connections target it.
s.nodes[-2]+='script = '+journal+'\n'
label('Heading','UI/Journal/Content','Journal',{'theme_override_fonts/font':georgia,'theme_override_font_sizes/font_size':'29'})
box('Write','UI/Journal/Content')
label('NoteLabel','UI/Journal/Content/Write','Note')
s.node('Note','TextEdit','UI/Journal/Content/Write',{'layout_mode':'2','custom_minimum_size':'Vector2(0,160)','wrap_mode':'1','theme_override_fonts/font':georgia,'theme_override_font_sizes/font_size':'17','scroll_fit_content_height':'false','context_menu_enabled':'true'})
s.connect('UI/Journal/Content/Write/Note','text_changed','text_changed','UI/Journal')
button('Save','UI/Journal/Content/Write','Keep this thought','save_note')
# Save's non-game combination is represented by its own keycap.
s.connections[-1]=s.connections[-1].replace('to="."','to="UI/Journal"')
button('History','UI/Journal/Content/Write','Past notes','show_list',plain=True); s.connections[-1]=s.connections[-1].replace('to="."','to="UI/Journal"')
box('Library','UI/Journal/Content')
for name,text,method in [('Back','Back to writing','back')]:
    button(name,'UI/Journal/Content/Library',text,method,plain=True); s.connections[-1]=s.connections[-1].replace('to="."','to="UI/Journal"')
label('Empty','UI/Journal/Content/Library','No saved notes.')
s.node('List','ScrollContainer','UI/Journal/Content/Library',{'layout_mode':'2','custom_minimum_size':'Vector2(0,280)','horizontal_scroll_mode':'0'})
box('Rows','UI/Journal/Content/Library/List'); s.nodes[-1]+='size_flags_horizontal = 3\n'
s.node('Read','ScrollContainer','UI/Journal/Content/Library',{'layout_mode':'2','custom_minimum_size':'Vector2(0,280)','horizontal_scroll_mode':'0'})
label('Text','UI/Journal/Content/Library/Read','',{'size_flags_horizontal':'3','autowrap_mode':'3','theme_override_fonts/font':georgia,'theme_override_font_sizes/font_size':'17'})
button('Remove','UI/Journal/Content/Library','Remove this note','ask_remove',plain=True); s.connections[-1]=s.connections[-1].replace('to="."','to="UI/Journal"')
box('Confirm','UI/Journal/Content/Library'); label('Prompt','UI/Journal/Content/Library/Confirm','Delete this note?')
for name,text,method in [('Delete','Delete','delete_note'),('Keep','Keep','keep_note')]:
    button(name,'UI/Journal/Content/Library/Confirm',text,method,plain=True); s.connections[-1]=s.connections[-1].replace('to="."','to="UI/Journal"')
box('Backup','UI/Journal/Content/Library')
for name,text,method in [('Export','Download notes','choose_export'),('Import','Restore notes','choose_import')]:
    button(name,'UI/Journal/Content/Library/Backup',text,method,plain=True); s.connections[-1]=s.connections[-1].replace('to="."','to="UI/Journal"')
label('Status','UI/Journal/Content','',{'autowrap_mode':'3'})
for name,mode,method in [('Import',0,'import_file'),('Export',4,'export_file')]:
    s.node(name,'FileDialog','UI/Journal',{'size':'Vector2i(800,600)','access':'2','file_mode':str(mode),'filters':'PackedStringArray("*.txt ; Hearthwillow notes")','use_native_dialog':'true','title':quoted('Restore notes' if name=='Import' else 'Download notes')})
    s.connect('UI/Journal/'+name,'file_selected',method,'UI/Journal')
s.connect('UI/Journal','moment','set_moment')
panel('Kind',360)
label('Heading','UI/Kind/Content','Your note',{'theme_override_fonts/font':georgia,'theme_override_font_sizes/font_size':'29'})
label('Note','UI/Kind/Content','',{'custom_minimum_size':'Vector2(0,160)','autowrap_mode':'3','theme_override_fonts/font':georgia,'theme_override_font_sizes/font_size':'26'})
button('Another','UI/Kind/Content','Another note','another_note','interact')
button('Keep','UI/Kind/Content','Keep','keep_kind_note','activity_8')
label('Status','UI/Kind/Content','',{'autowrap_mode':'3'})
panel('Breathe',340,False)
label('Heading','UI/Breathe/Content','Breathe',{'theme_override_font_sizes/font_size':'23'})
button('Feed','UI/Breathe/Content','Feed the ducks','feed_pond','talk')
s.node('Orbit','Control','UI/Breathe/Content',{'layout_mode':'2','custom_minimum_size':'Vector2(0,150)','script':orbit,'mouse_filter':'2'})
s.node('Phase','Label','UI/Breathe/Content/Orbit',{'offset_left':'0.0','offset_top':'42.0','offset_right':'310.0','offset_bottom':'68.0','horizontal_alignment':'1','text':'"Ready"'})
s.node('Count','Label','UI/Breathe/Content/Orbit',{'offset_top':'66.0','offset_right':'310.0','offset_bottom':'126.0','horizontal_alignment':'1','theme_override_fonts/font':georgia,'theme_override_font_sizes/font_size':'46','text':'"~"'})
button('Toggle','UI/Breathe/Content','Begin','toggle_breathing','jump')
button('Reset','UI/Breathe/Content','Reset','reset_breathing','unstuck')
for i,text in enumerate(['Calm · 4–4–6','Box · 4–4–4–4','Slow · 4–7–8']): button('Pattern'+str(i),'UI/Breathe/Content',text,'set_pattern','activity_'+str(i+1),f'[{i}]')
label('Status','UI/Breathe/Content','',{'autowrap_mode':'3'})
# Outside panels, concise controls keep the active scene visible.
for name,text,method,action,y in [('Enter','Open your journal','enter_nearby','interact',940),('Leave','Leave','leave','release_mouse',974),('Collapse','Hide controls','toggle_controls','toggle_activity',918)]:
    button(name,'UI',text,method,action)
    # Locate the button node; helper added descendants after it.
    for i in range(len(s.nodes)-1,-1,-1):
        if s.nodes[i].startswith(f'[node name="{name}" type="Button" parent="UI"]'):
            s.nodes[i]+=f'visible = false\noffset_left = 1520.0\noffset_right = 1892.0\noffset_top = {y}.0\noffset_bottom = {y+44}.0\n'; break
s.save('scenes/quiet_places.tscn')
# List rows are genuine dynamic content instanced from this editable template.
r=Scene(); rf=r.ext('Theme','res://scenes/journal_theme.tres','paper'); ff=r.ext('FontFile','res://assets/fonts/Georgia.tres','display'); bg=r.sub('StyleBoxFlat','row',{'bg_color':'Color(1,0.985,0.95,1)','border_width_bottom':'1','border_color':'Color(0.82,0.86,0.80,1)','content_margin_left':'12.0','content_margin_right':'12.0','content_margin_top':'10.0','content_margin_bottom':'10.0'})
r.node('NoteRow','Button',props={'custom_minimum_size':'Vector2(0,70)','size_flags_horizontal':'3','theme':rf,'theme_override_styles/normal':bg,'theme_override_styles/hover':bg,'theme_override_styles/pressed':bg})
r.node('Content','VBoxContainer','.',{'layout_mode':'0','anchors_preset':'15','anchor_right':'1.0','anchor_bottom':'1.0','offset_left':'12.0','offset_top':'8.0','offset_right':'-12.0','offset_bottom':'-8.0','mouse_filter':'2'})
r.node('Preview','Label','Content',{'layout_mode':'2','text':'""','text_overrun_behavior':'3','theme_override_fonts/font':ff,'theme_override_font_sizes/font_size':'17','mouse_filter':'2'})
r.node('Date','Label','Content',{'layout_mode':'2','text':'""','theme_override_font_sizes/font_size':'12','mouse_filter':'2'})
r.save('scenes/journal_note_row.tscn')
print('Saved quiet activities UI and note row.')
