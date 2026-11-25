#!/usr/bin/env python3
"""Print X11 geometry/attributes for the given window ids (or the whole tree)."""
import ctypes, sys

X = ctypes.CDLL("libX11.so.6")
X.XOpenDisplay.restype = ctypes.c_void_p
X.XOpenDisplay.argtypes = [ctypes.c_char_p]
X.XDefaultRootWindow.restype = ctypes.c_ulong
X.XDefaultRootWindow.argtypes = [ctypes.c_void_p]

class XWindowAttributes(ctypes.Structure):
    _fields_ = [
        ("x", ctypes.c_int), ("y", ctypes.c_int),
        ("width", ctypes.c_int), ("height", ctypes.c_int),
        ("border_width", ctypes.c_int), ("depth", ctypes.c_int),
        ("visual", ctypes.c_void_p), ("root", ctypes.c_ulong),
        ("class_", ctypes.c_int), ("bit_gravity", ctypes.c_int),
        ("win_gravity", ctypes.c_int), ("backing_store", ctypes.c_int),
        ("backing_planes", ctypes.c_ulong), ("backing_pixel", ctypes.c_ulong),
        ("save_under", ctypes.c_int), ("colormap", ctypes.c_ulong),
        ("map_installed", ctypes.c_int), ("map_state", ctypes.c_int),
        ("all_event_masks", ctypes.c_long), ("your_event_mask", ctypes.c_long),
        ("do_not_propagate_mask", ctypes.c_long), ("override_redirect", ctypes.c_int),
        ("screen", ctypes.c_void_p),
    ]

X.XGetWindowAttributes.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(XWindowAttributes)]
X.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong,
                         ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong),
                         ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)), ctypes.POINTER(ctypes.c_uint)]
X.XFetchName.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_char_p)]
X.XGetGeometry.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong),
                           ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int),
                           ctypes.POINTER(ctypes.c_uint), ctypes.POINTER(ctypes.c_uint),
                           ctypes.POINTER(ctypes.c_uint), ctypes.POINTER(ctypes.c_uint)]
X.XTranslateCoordinates.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong,
                                    ctypes.c_int, ctypes.c_int,
                                    ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int),
                                    ctypes.POINTER(ctypes.c_ulong)]

dpy = X.XOpenDisplay(None)
if not dpy:
    sys.exit("cannot open display")
root = X.XDefaultRootWindow(dpy)

def name(w):
    p = ctypes.c_char_p()
    if X.XFetchName(dpy, w, ctypes.byref(p)) and p.value:
        return p.value.decode("utf-8", "replace")
    return ""

def info(w):
    a = XWindowAttributes()
    if not X.XGetWindowAttributes(dpy, w, ctypes.byref(a)):
        return f"{w:#x} <no attributes>"
    rx, ry = ctypes.c_int(), ctypes.c_int()
    child = ctypes.c_ulong()
    X.XTranslateCoordinates(dpy, w, root, 0, 0, ctypes.byref(rx), ctypes.byref(ry), ctypes.byref(child))
    return (f"{w:#x} '{name(w)}' abs=({rx.value},{ry.value}) size={a.width}x{a.height} "
            f"border={a.border_width} depth={a.depth} map_state={a.map_state} "
            f"override_redirect={a.override_redirect} class={a.class_}")

def tree(w, depth=0):
    out = ["  " * depth + info(w)]
    rr, pr = ctypes.c_ulong(), ctypes.c_ulong()
    kids = ctypes.POINTER(ctypes.c_ulong)()
    n = ctypes.c_uint()
    if X.XQueryTree(dpy, w, ctypes.byref(rr), ctypes.byref(pr), ctypes.byref(kids), ctypes.byref(n)) and n.value:
        for i in range(n.value):
            out.append(tree(kids[i], depth + 1))
    return "\n".join(out)

for arg in sys.argv[1:] or ["root"]:
    if arg == "root":
        print(tree(root))
    else:
        print(info(int(arg, 0)))
