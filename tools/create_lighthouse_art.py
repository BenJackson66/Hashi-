#!/usr/bin/env python3
"""Original layered vector scene: each Story win restores one visible detail."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/landscape';DEST.mkdir(exist_ok=True)
DEFS='''<defs>
 <linearGradient id="sky" x2="0" y2="1"><stop stop-color="#eac7ad"/><stop offset="1" stop-color="#f6e9c9"/></linearGradient>
 <linearGradient id="sea" x2=".2" y2="1"><stop stop-color="#9bbab5"/><stop offset="1" stop-color="#648f91"/></linearGradient>
 <linearGradient id="rock" x2=".1" y2="1"><stop stop-color="#a8a487"/><stop offset="1" stop-color="#777f70"/></linearGradient>
 <linearGradient id="grass" x2=".3" y2="1"><stop stop-color="#b7c490"/><stop offset="1" stop-color="#8fa67a"/></linearGradient>
 <linearGradient id="wall" x2="1" y2=".2"><stop stop-color="#faf0d6"/><stop offset="1" stop-color="#d9cfb1"/></linearGradient>
 <radialGradient id="glow"><stop stop-color="#ffe7a1" stop-opacity=".72"/><stop offset="1" stop-color="#ffe7a1" stop-opacity="0"/></radialGradient>
</defs>'''
def svg(body):return '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="760" viewBox="0 0 800 760">'+DEFS+'<g stroke-linecap="round" stroke-linejoin="round">'+body+'</g></svg>'
def save(name,body):(DEST/(name+'.svg')).write_text(svg(body))
base='''
<rect width="800" height="760" rx="42" fill="url(#sky)"/>
<circle cx="180" cy="166" r="65" fill="#f7e6b5" opacity=".85"/>
<path d="M0 284 Q95 241 190 278 Q277 215 360 280 Q455 242 537 281 Q662 223 800 270 L800 369H0Z" fill="#b9c4af"/>
<path d="M0 316 Q118 281 220 322 Q319 284 415 326 Q602 273 800 306 V760H0Z" fill="url(#sea)"/>
<path d="M43 142q22-19 45 0q26-29 55-3q23-9 40 9q-58 14-140-6M499 108q26-21 53-1q39-32 72 2q37-10 58 12q-81 8-183-13M635 202q21-18 44 0q22-22 48 0q15-7 27 8q-62 8-119-8" fill="#f8edda" opacity=".65"/>
<path d="M342 196q12-13 24 0q12-13 24 0M432 154q9-9 18 0q9-9 18 0" fill="none" stroke="#818c82" stroke-width="3"/>
<path d="M2 402q76-16 145 1M38 689q90-20 181-1M529 675q83-11 179 4M600 354q58-10 125-3M35 357q49-7 87 0M15 526q34-9 63-2M354 717q75-15 136-3" stroke="#c8d6c4" fill="none" stroke-width="3" opacity=".5"/>
<ellipse cx="405" cy="578" rx="330" ry="94" fill="#537e7d" opacity=".38"/>
<path d="M103 465C148 379 266 375 344 391C410 326 524 307 600 353C675 353 732 394 738 449L701 554C653 606 567 611 506 589C415 651 287 639 236 596C158 604 106 548 103 465Z" fill="url(#rock)" stroke="#7c8978" stroke-width="3"/>
<path d="M130 502l27 64 72 12 30 39M274 550l20 66M339 544l-8 78M412 535l10 69M504 494l7 93M611 463l17 122M691 459l-19 88" fill="none" stroke="#6d7c6d" stroke-width="4" opacity=".45"/>
<path d="M108 459C143 381 260 363 340 390C402 327 524 305 600 350C664 341 731 387 739 439C715 484 643 504 575 484C521 533 432 553 354 540C279 584 188 548 155 520C126 516 101 488 108 459Z" fill="url(#grass)" stroke="#899e76" stroke-width="3"/>
<path d="M121 475q87 38 141 12M337 407q82-48 153-38M529 468q85-34 162-33" fill="none" stroke="#cbd2a0" stroke-width="6" opacity=".5"/>
<path d="M172 497q70-70 171-57q80 3 119-26q55-35 128-13" fill="none" stroke="#9aa783" stroke-width="24" stroke-dasharray="2 16" opacity=".7"/>
<!-- Weathered tower: restoration layers repaint it without moving the silhouette. -->
<ellipse cx="599" cy="411" rx="64" ry="17" fill="#687c67" opacity=".28"/>
<path d="M565 263h59l18 145q-42 18-83 0Z" fill="#c1bda3" stroke="#8e9880" stroke-width="3"/>
<path d="M565 264l59 0-5-39-51 0Z" fill="#8b9a89" stroke="#768977" stroke-width="3"/>
<path d="M558 224l37-27 39 27Z" fill="#839184"/>
<path d="M571 264v-36M588 263v-43M608 264v-39M619 264v-35" stroke="#6f8377" stroke-width="5"/>
<path d="M582 408v-29q11-18 23 0v33" fill="#71816c"/>
<path d="M578 302l12-4M612 339l10 4M569 367l14-4M605 391l14 2" stroke="#a1a48a" stroke-width="4"/>
<!-- The small cottage, closed and waiting. -->
<ellipse cx="391" cy="478" rx="79" ry="20" fill="#6e886e" opacity=".28"/>
<path d="M328 416l59-39 75 42v60l-72 13-62-21Z" fill="#bcba96" stroke="#87977a" stroke-width="3"/>
<path d="M314 416l70-55 94 58-17 8-78-42-56 43Z" fill="#9b9d82"/>
<path d="M347 428h27v38h-27ZM410 430h26v28h-26Z" fill="#899880"/>
<path d="M391 486v-36l15-4v37" fill="#798c76"/>
<path d="M346 431l25 30M411 434l23 20" stroke="#a9ac8c" stroke-width="5"/>
<!-- Broken dock; calm, never a character in danger. -->
<path d="M132 519l-6 63M175 524l-3 74M111 571l88 20" stroke="#758d7c" stroke-width="12"/>
<path d="M126 541l50 13M127 558l17 5M157 568l18 4" stroke="#a5ac89" stroke-width="10"/>
<path d="M191 545l12 30M105 608l41 10" stroke="#7d9584" stroke-width="7"/>
'''
# Shore pebbles, grasses and quiet ink details give the scene a hand-made finish.
for x,y,r in [(100,580,16),(732,508,18),(279,644,13),(681,603,10),(79,553,8)]:
 base+=f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r*.48}" fill="#a4b6a0"/><path d="M{x-r*.5} {y-2}h{r}" stroke="#cbd2b4" stroke-width="2"/>'
for x,y in [(204,441),(283,410),(480,377),(655,411),(282,514),(512,493),(156,476),(674,467)]:
 base+=f'<path d="M{x} {y}l-4-11m4 11 2-16m-2 16 8-10" fill="none" stroke="#718d64" stroke-width="3"/>'
base+='<path d="M123 611q37 9 72 7M562 625q40 7 76-6M720 553q23-13 31-30" stroke="#cad9c7" stroke-width="3" fill="none" opacity=".7"/>'
save('coast',base)
layers=[]
layers.append('''<path d="M121 535l-4 78M177 547l-2 78M111 603l76 17" stroke="#756a51" stroke-width="12"/><path d="M123 536l-2 70M179 547l-2 71" stroke="#b7a378" stroke-width="4"/>''')
layers.append('''<path d="M126 529l62 16-10 76-65-17Z" fill="#c4ad7d" stroke="#8b7d5c" stroke-width="3"/><path d="M124 544l61 16M121 561l61 16M119 578l61 16M116 595l62 16" stroke="#928260" stroke-width="3"/><path d="M127 527v-18m58 34v-17m-64 53v-17m58 33v-17M127 513l58 17M122 563l57 15" stroke="#f0d8a2" stroke-width="5"/>''')
layers.append('''<ellipse cx="202" cy="650" rx="64" ry="12" fill="#577d7b" opacity=".4"/><path d="M149 620q62 35 115-4l-18 38q-51 20-87-8Z" fill="#c1785e" stroke="#856956" stroke-width="3"/><path d="M150 621q64 34 113-4" stroke="#edce9e" stroke-width="7" fill="none"/><path d="M204 627v-88l40 72-40-5Z" fill="#f3e8c8" stroke="#c8ba96" stroke-width="2"/><path d="M203 541v87" stroke="#7e7758" stroke-width="4"/><path d="M178 618l-3-22" stroke="#d2bf90" stroke-width="2"/><path d="M151 516v-39l30 11-30 11" fill="#d79772" stroke="#8d795c" stroke-width="3"/>''')
layers.append('''<path d="M187 501q54-65 139-54q102 13 148-30q48-34 111-16" fill="none" stroke="#d6c797" stroke-width="21"/><path d="M191 499q65-59 139-46q105 10 144-30q56-36 106-17" fill="none" stroke="#e4d8ae" stroke-width="6" stroke-dasharray="7 16"/>''')
layers.append('''<path d="M247 443l61-3 5 28-60 7Z" fill="#b99e70" stroke="#877557" stroke-width="3"/><path d="M257 446l2 24m11-25 2 23m10-24 2 23m10-24 2 22M249 443v-16m59 13v-16m-59 3 59-3" stroke="#e6cda0" stroke-width="4"/><path d="M476 403l35-21m8-3 32-4" stroke="#f0dbad" stroke-width="4"/><path d="M480 402v-17m29-2v-17m15 12v-16m25 12v-17" stroke="#e1c593" stroke-width="5"/>''')
flowers=''
for x,y in [(217,468),(230,452),(327,485),(344,477),(490,437),(512,430),(541,426),(203,481),(307,511),(662,453)]:
 flowers+=f'<path d="M{x} {y+8}v-13m0 10-7-4m7 1 7-6" stroke="#6d8e62" stroke-width="2"/><circle cx="{x}" cy="{y-7}" r="5" fill="#f4dfaa"/><circle cx="{x+4}" cy="{y-3}" r="4" fill="#d99581"/>'
layers.append(flowers)
layers.append('''<path d="M329 417l58-39 75 41v59l-72 14-61-22Z" fill="url(#wall)" stroke="#a59777" stroke-width="3"/><path d="M390 400v90" stroke="#c5b695" stroke-width="2"/><path d="M314 416l70-55 94 58-17 8-78-42-56 43Z" fill="#bc7c60" stroke="#916d54" stroke-width="3"/><path d="M329 413l52-40 77 47M343 405l39-29 62 35" fill="none" stroke="#d69b77" stroke-width="3"/><path d="M433 389v-30h16v40" fill="#ddd0ad" stroke="#a79878" stroke-width="3"/>''')
layers.append('''<path d="M347 429h27v37h-27ZM410 430h27v28h-27Z" fill="#f8d58d" stroke="#9b8966" stroke-width="4"/><path d="M360 430v35m-12-19h25m51-15v27m-13-13h25" stroke="#b29b71" stroke-width="3"/><path d="M382 487v-35q12-17 24-5v36" fill="#71927b" stroke="#71816a" stroke-width="3"/><circle cx="399" cy="467" r="2" fill="#edd7a0"/><path d="M342 470h38M407 462h34" stroke="#c6ab7b" stroke-width="5"/>''')
garden='''<path d="M328 488q-15-20-27-7q-8-29-25-12q-20 4-8 23q21 14 60-4M434 484q-8-26 13-29q15-16 25 4q24 0 16 22q-23 17-54 3" fill="#78996f"/><path d="M397 496l-16 8h38l-13-10" fill="#bbaa86"/><path d="M464 493h38m-32 0v18m26-18v18" stroke="#a18562" stroke-width="5"/><path d="M500 470h17l-3 25h-10Z" fill="#bb8067"/><path d="M508 470l-9-15m9 15 8-21m-8 21-1-28" stroke="#74946e" stroke-width="4"/>'''
for x,y in [(279,477),(295,480),(311,486),(447,470),(464,476),(477,468)]:garden+=f'<circle cx="{x}" cy="{y}" r="4" fill="#e4c88b"/>'
layers.append(garden)
layers.append('''<path d="M565 263h59l18 145q-42 18-83 0Z" fill="url(#wall)" stroke="#b2aa8c" stroke-width="3"/><path d="M561 348l-2 27q41 16 79-1l-3-27q-34 15-74 1" fill="#c58b70"/><path d="M581 410v-29q11-17 24-1v32" fill="#6a8b7e" stroke="#8e8a6c" stroke-width="3"/><path d="M586 297v-13q9-9 17-1v15" fill="#839f95" stroke="#b8ae8d" stroke-width="3"/><path d="M554 265h79m-76 9h73" stroke="#bfa678" stroke-width="6"/>''')
layers.append('''<path d="M562 262l3-38h59l4 38Z" fill="#e5d5aa" stroke="#8c8770" stroke-width="3"/><path d="M570 230h46v27h-46Z" fill="#799c9a"/><path d="M584 229v29m18-29v29" stroke="#d8c89b" stroke-width="4"/><path d="M554 224l40-27 42 27Z" fill="#a76854" stroke="#876c58" stroke-width="3"/><path d="M594 198v-17" stroke="#826f59" stroke-width="3"/><path d="M583 184h22l-8-5" stroke="#826f59" stroke-width="3" fill="none"/><path d="M549 267v-15m14 17v-14m17 15v-15m18 16v-16m18 14v-15m18 12v-15M549 253l86-2" stroke="#657d73" stroke-width="3"/>''')
layers.append('''<circle cx="594" cy="242" r="126" fill="url(#glow)"/><path d="M583 237L214 157l-6 52 375 38ZM605 237l194-76v63l-194 23Z" fill="#ffebad" opacity=".28"/><path d="M571 230h45v26h-45Z" fill="#f8d586"/><path d="M584 229v29m18-29v29" stroke="#c4b181" stroke-width="4"/><ellipse cx="594" cy="243" rx="8" ry="11" fill="#fff4c7"/><path d="M593 499q31 5 56-5m-43 17 52-3m-38 14 42-3" fill="none" stroke="#e0d7ab" stroke-width="3" opacity=".8"/>''')
names=['pilings','deck','boat','trail','footbridge','flowers','roof','windows','garden','tower','lantern','light']
for name,body in zip(names,layers):save(name,body)
icons={
'boat':'<path d="M4 15h17l-3 5H7Z M12 3v12 M12 4l7 8h-7 M3 22q3-2 6 0q3-2 6 0q3-2 6 0"/>',
'bridge':'<path d="M3 19V7m18 12V7M3 10q9 11 18 0M3 19h18M7 14v5m5-3v3m5-5v5"/>',
'house':'<path d="M3 11 12 3l9 8M5 10v11h14V10M10 21v-7h5v7M7 11h2"/>',
'lighthouse':'<path d="M8 20 9 9h6l1 11M8 9h8M9 9V5h6v4M8 5l4-3 4 3M6 21h12M3 7l3 1m15-1-3 1M10 15h4"/>',
'sound':'<path d="M3 9h4l5-4v14l-5-4H3ZM16 8q4 4 0 8m3-11q7 7 0 14"/>',
'mute':'<path d="M3 9h4l5-4v14l-5-4H3ZM16 9l6 6m0-6-6 6"/>',
}
for name,body in icons.items():(ROOT/'assets/icons'/f'{name}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="white" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'+body+'</g></svg>')
(DEST/'LICENSE.txt').write_text('Original layered vector illustration created for Hashi, 2026. No third-party artwork. Generated from tools/create_lighthouse_art.py.\n')
print('13 scene layers and 6 matching interface icons generated.')
