# -*- coding: utf-8 -*-

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

from gallery_dl.extractor import nhentai

__tests__ = (
{
    "#url"     : "https://nhentai.net/favorites/",
    "#category": ("nhentai", "favorite"),
    "#class"   : nhentai.NhentaiFavoriteExtractor,
    "#auth"    : True,
},

{
    "#url"     : "https://nhentai.net/favorites/?q=language:english",
    "#category": ("nhentai", "favorite"),
    "#class"   : nhentai.NhentaiFavoriteExtractor,
    "#auth"    : True,
},
)
