# -*- coding: utf-8 -*-

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

from gallery_dl.extractor import myhentaicomics


__tests__ = (
{
    "#url"     : "https://myhentaicomics.com/gallery/thumbnails/30553",
    "#category": ("", "myhentaicomics", "gallery"),
    "#class"   : myhentaicomics.MyhentaicomicsGalleryExtractor,
    "#pattern" : r"https://cdn\.myhentaicomics\.com/mhc/images/[^/]+/original/[^?]+",

    "gallery_id": 30553,
    "title"     : str,
    "artist"    : list,
    "group"     : list,
    "parodies"  : list,
    "tags"      : list,
},

{
    "#url"     : "https://myhentaicomics.com/g/30553",
    "#category": ("", "myhentaicomics", "gallery"),
    "#class"   : myhentaicomics.MyhentaicomicsGalleryExtractor,
},

{
    "#url"     : "https://myhentaicomics.com/g/category/123",
    "#category": ("", "myhentaicomics", "tag"),
    "#class"   : myhentaicomics.MyhentaicomicsTagExtractor,
},

{
    "#url"     : "https://myhentaicomics.com/g/artist/1?sorting=favorite",
    "#category": ("", "myhentaicomics", "tag"),
    "#class"   : myhentaicomics.MyhentaicomicsTagExtractor,
},

)
