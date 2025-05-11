const std = @import("std");
const c = @cImport({
    @cInclude("OpenGL/gl.h");
});

// Export OpenGL constants
pub const TEXTURE_2D = c.GL_TEXTURE_2D;
pub const FRAMEBUFFER = c.GL_FRAMEBUFFER;
pub const COLOR_ATTACHMENT0 = c.GL_COLOR_ATTACHMENT0;
pub const RGB = c.GL_RGB;
pub const UNSIGNED_BYTE = c.GL_UNSIGNED_BYTE;
pub const COLOR_BUFFER_BIT = c.GL_COLOR_BUFFER_BIT;
pub const BLEND = c.GL_BLEND;
pub const NEAREST = c.GL_NEAREST;
pub const LINEAR = c.GL_LINEAR;
pub const CLAMP_TO_EDGE = c.GL_CLAMP_TO_EDGE;
pub const TEXTURE_WRAP_S = c.GL_TEXTURE_WRAP_S;
pub const TEXTURE_WRAP_T = c.GL_TEXTURE_WRAP_T;
pub const TEXTURE_MAG_FILTER = c.GL_TEXTURE_MAG_FILTER;
pub const TEXTURE_MIN_FILTER = c.GL_TEXTURE_MIN_FILTER;
pub const QUADS = c.GL_QUADS;
pub const PROJECTION = c.GL_PROJECTION;
pub const MODELVIEW = c.GL_MODELVIEW;

// Add OpenGL framebuffer status constants
pub const FRAMEBUFFER_COMPLETE = c.GL_FRAMEBUFFER_COMPLETE;
pub const NO_ERROR = c.GL_NO_ERROR;

// Export OpenGL functions
pub const enable = c.glEnable;
pub const disable = c.glDisable;
pub const genFramebuffers = c.glGenFramebuffers;
pub const genTextures = c.glGenTextures;
pub const bindFramebuffer = c.glBindFramebuffer;
pub const bindTexture = c.glBindTexture;
pub const texImage2D = c.glTexImage2D;
pub const texParameteri = c.glTexParameteri;
pub const framebufferTexture2D = c.glFramebufferTexture2D;
pub const viewport = c.glViewport;
pub const clearColor = c.glClearColor;
pub const clear = c.glClear;
pub const texSubImage2D = c.glTexSubImage2D;
pub const deleteFramebuffers = c.glDeleteFramebuffers;
pub const deleteTextures = c.glDeleteTextures;
pub const matrixMode = c.glMatrixMode;
pub const loadIdentity = c.glLoadIdentity;
pub const ortho = c.glOrtho;
pub const begin = c.glBegin;
pub const end = c.glEnd;
pub const texCoord2d = c.glTexCoord2d;
pub const vertex2d = c.glVertex2d;
pub const getString = c.glGetString;
pub const VERSION = c.GL_VERSION;
pub const color4f = c.glColor4f;
pub const blendFunc = c.glBlendFunc;
pub const SRC_ALPHA = c.GL_SRC_ALPHA;
pub const ONE_MINUS_SRC_ALPHA = c.GL_ONE_MINUS_SRC_ALPHA;

// Add check functions
pub const checkFramebufferStatus = c.glCheckFramebufferStatus;
pub const getError = c.glGetError;
