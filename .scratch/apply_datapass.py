import json, collections
P='WAFishMap/Resources/fisheries.json'
raw=open(P).read()
d=json.loads(raw, object_pairs_hook=collections.OrderedDict)
A={a['areaName']:a for a in d['areas']}
fw=d['freshwater']; C=fw['byCounty']
log=[]
def row(lst,name):
    r=[s for s in lst if s['species']==name]; assert len(r)==1,(name,len(r)); return r[0]
def setm(lst,name,best_old,good_old,best,good,tag):
    r=row(lst,name); assert r['bestMonths']==best_old and r.get('goodMonths',[])==good_old,(tag,name,r['bestMonths'],r.get('goodMonths'))
    r['bestMonths']=best; r['goodMonths']=good; log.append(tag)
def drop(lst,name,tag):
    row(lst,name); lst[:]=[s for s in lst if s['species']!=name]; log.append(tag)
def note(lst,name,old,new,tag,field='note'):
    r=row(lst,name); assert old in r[field],(tag,r[field]); r[field]=r[field].replace(old,new); log.append(tag)
def sp(a): return A[a]['species']

# ---- Puget Sound ----
setm(sp('5'),'Resident Chinook (Blackmouth)',[3,4],[2],[4],[],'P1')
setm(sp('6'),'Chinook Salmon',[7,8],[9],[7],[8],'P2')
drop(sp('7'),'Resident Chinook (Blackmouth)','P3')
setm(sp('7'),'Coho Salmon',[8,9],[10],[8,9],[],'P4')
setm(sp('8-2'),'Coho Salmon',[9,10],[8],[9],[8],'P5')
setm(sp('9'),'Chinook Salmon',[7,8],[9],[7],[8],'P6')
setm(sp('9'),'Coho Salmon',[9,10],[8,11],[8,9],[],'P7')
setm(sp('10'),'Chum Salmon',[10,11],[9,12],[10,11],[],'P8')
setm(sp('11'),'Chum Salmon',[10,11],[9,12],[10,11],[],'P9')
for a in ('10','11'): setm(sp(a),'Resident Chinook (Blackmouth)',[3,4],[2],[4],[3],'P10+U-blackmouth-'+a)
setm(sp('12'),'Chum Salmon',[10,11],[9,12],[11],[10],'P11')
setm(sp('12'),'Coho Salmon',[9,10],[8,11],[9,10],[8],'P12')
drop(sp('12'),'Lingcod','P13')
drop(sp('13'),'Chum Salmon','P14')
drop(sp('13'),'Dungeness Crab','P15')
drop(sp('13'),'Crab Snaring (shore)','P16')
for a in ('5','6','7','8-1','8-2','9','10','11','13'):
    setm(sp(a),'Lingcod',[5,6],[4],[5,6],[],'P18-'+a)
for a in ('8-1','9','10','11','12'):
    setm(sp(a),'Crab Snaring (shore)',[7,8,9],[6,10],[7,8],[9],'P19-'+a)
setm(sp('11'),'Dungeness Crab',[7,8],[9],[7,8],[],'P20')
setm(sp('11'),'Market Squid',[10,11,12,1],[2],[11,12,1],[10,2],'P21')
for a in ('5','6'): setm(sp(a),'Halibut',[5,6],[7,8],[5,6],[4,8,9],'P22-'+a)
setm(sp('7'),'Halibut',[5,6],[4],[5,6],[4,8,9],'U-halibut-7')

# ---- Coast ----
setm(sp('2-1'),'Fall Chinook',[9],[8,10],[8],[9],'C1')
for a in ('2-1','2-2'): setm(sp(a),'Dungeness Crab',[7,8,9],[10],[7,8],[6,9],'C2-'+a)
for a in ('1','2','2-2'):
    r=row(sp(a),'Razor Clams'); assert r['bestTime']=='Evening low tides (dig openers set by WDFW)',r['bestTime']
    r['bestTime']='Evening low tides in fall and winter, morning tides in spring (dig openers set by WDFW)'; log.append('C3-'+a)
setm(sp('1'),'Buoy 10 Salmon (Columbia mouth)',[8,9],[7],[8,9],[],'C4')

# ---- Freshwater ----
bk=row(fw['byWaterbody']['Baker Lake'],'Sockeye Salmon')
assert bk['goodMonths']==[6]; bk['goodMonths']=[]; log.append('F2')
bk['note']="Opens on a set summer date regardless of how many fish are in the lake; sockeye reach it by the Baker River trap-and-haul. Confirm dates with WDFW."; log.append('F1')
drop(C['Chelan'],'Chinook Salmon','F3/F4')
drop(C['King'],'Coho Salmon','F5')
drop(C['Snohomish'],'Smallmouth Bass','F6')
drop(C['Spokane'],'Redband Trout','F7')
for c in ('Stevens','Ferry'):
    for s in ('Kokanee','Walleye','Rainbow Trout'): drop(C[c],s,f'F-{c}-{s}')
drop(C['Douglas'],'Rainbow Trout (triploid)','F16')
drop(C['Douglas'],'Walleye','F17')
drop(C['Yakima'],'Smallmouth Bass','F18')
drop(C['Yakima'],'Channel Catfish','U27')
drop(C['Kittitas'],'Rainbow Trout (wild)','F19')
drop(C['Kittitas'],'Cutthroat Trout','F20')
for c in list(C):
    if not C[c]: del C[c]; log.append('empty-county-'+c)
for c in ('Pierce','Thurston'):
    r=row(C[c],'Rock Bass'); print(c,'rock bass note:',r.get('note'))
print('Mason perch note:',row(C['Mason'],'Yellow Perch').get('note'))
print('Area 5 Chinook note:',row(sp('5'),'Chinook Salmon').get('note'))
print('Area 13 blackmouth note:',row(sp('13'),'Resident Chinook (Blackmouth)').get('note'))
print('Area 5 blackmouth note:',row(sp('5'),'Resident Chinook (Blackmouth)').get('note'))
json.dump(d,open(P,'w'),indent=2,ensure_ascii=False); open(P,'a').write('\n')
print(len(log),'edits applied')
