(function () {
  'use strict';

  const instances = new Map();
  let support;

  const vertexSource = `#version 300 es
    in vec2 a_position;
    void main() {
      gl_Position = vec4(a_position, 0.0, 1.0);
    }
  `;

  const vertexSourceWebGL1 = `
    attribute vec2 a_position;
    void main() {
      gl_Position = vec4(a_position, 0.0, 1.0);
    }
  `;

  const fragmentSource = `#version 300 es
    precision highp float;

    uniform vec2 u_resolution;
    uniform float u_dpr;
    uniform float u_progress;
    uniform float u_time;
    uniform sampler2D u_edge;

    out vec4 outColor;

    float hash21(vec2 p) {
      p = fract(p * vec2(123.34, 456.21));
      p += dot(p, p + 45.32);
      return fract(p.x * p.y);
    }

    float noise(vec2 p) {
      vec2 i = floor(p);
      vec2 f = fract(p);
      f = f * f * (3.0 - 2.0 * f);
      return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + 1.0), f.x),
        f.y
      );
    }

    float fbm(vec2 p) {
      float value = 0.0;
      float amplitude = 0.5;
      for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        amplitude *= 0.5;
      }
      return value;
    }

    float fibreField(vec2 uv, float distanceToEdge, float cellSize, float seed) {
      vec2 grid = uv * u_resolution / (cellSize * u_dpr);
      vec2 cell = floor(grid);
      vec2 local = fract(grid) - 0.5;
      float random = hash21(cell + seed);
      vec2 jitter = vec2(
        hash21(cell + seed + 13.7),
        hash21(cell + seed + 41.9)
      ) - 0.5;
      float radius = mix(0.055, 0.24, hash21(cell + seed + 7.3));
      float fleck = smoothstep(radius, radius * 0.28, length(local - jitter * 0.72));
      float px = u_dpr / u_resolution.y;
      float nearEdge = smoothstep(-58.0 * px, -1.5 * px, distanceToEdge)
        * (1.0 - smoothstep(-1.5 * px, 5.0 * px, distanceToEdge));
      return fleck * step(mix(0.84, 0.48, nearEdge), random) * nearEdge;
    }

    void main() {
      vec2 uv = gl_FragCoord.xy / u_resolution;
      float screenY = 1.0 - uv.y;
      float front = texture(u_edge, vec2(uv.x, 0.5)).r;
      float px = u_dpr / u_resolution.y;

      // A second, two-dimensional noise field breaks up the sampled burn
      // contour like the normal/noise distortion in Shopify's transition.
      float surfaceNoise = fbm(vec2(uv.x * 22.0, screenY * 10.0 - u_time * 0.025));
      float fineNoise = noise(vec2(uv.x * 210.0, screenY * 125.0 + u_time * 0.04));
      float d = screenY - front
        + (surfaceNoise - 0.5) * 5.5 * px
        + (fineNoise - 0.5) * 1.6 * px;

      float burnedSide = 1.0 - smoothstep(-1.5 * px, 2.0 * px, d);
      float revealedSide = smoothstep(-1.0 * px, 3.0 * px, d);
      float heat = sin(clamp(u_progress, 0.0, 1.0) * 3.14159265);

      // The disappearing splash is the upper layer, so its cast shadow can
      // only fall downward onto the home page being revealed beneath it.
      float castShadow = exp(-abs(d - 15.0 * px) / (15.0 * px)) * revealedSide;
      float charEdge = exp(-abs(d + 2.5 * px) / (3.4 * px)) * burnedSide;
      float greyAsh = exp(-abs(d + 1.5 * px) / (5.8 * px));
      float whiteAsh = exp(-abs(d - 1.4 * px) / (6.4 * px));
      float hotLine = exp(-abs(d - 2.1 * px) / (1.05 * px));
      float chalkPattern = smoothstep(
        0.34,
        0.74,
        fbm(vec2(uv.x * 96.0, screenY * 82.0 + surfaceNoise * 4.0))
      );
      float chalkFuzz = exp(-abs(d + 1.5 * px) / (8.5 * px))
        * burnedSide
        * mix(0.28, 1.0, chalkPattern);

      float tinyFibres = fibreField(uv, d, 2.25, 5.0);
      float fibres = fibreField(uv, d, 4.6, 29.0);
      float clumps = fibreField(uv, d, 8.5, 83.0);
      float fibreBand = smoothstep(-52.0 * px, -2.0 * px, d)
        * (1.0 - smoothstep(-2.0 * px, 5.0 * px, d));
      float cottonNoise = fbm(vec2(
        uv.x * 178.0 + surfaceNoise * 7.0,
        screenY * 132.0 - u_time * 0.018
      ));
      float cotton = smoothstep(
        mix(0.78, 0.36, fibreBand),
        0.88,
        cottonNoise
      ) * fibreBand;
      float tornGrain = smoothstep(
        0.66,
        0.9,
        noise(vec2(uv.x * 340.0, screenY * 225.0))
      ) * fibreBand;
      float fibreAmount = clamp(
        tinyFibres + fibres + clumps + cotton * 0.96 + tornGrain * 0.62,
        0.0,
        1.0
      );
      float fibreTone = hash21(floor(uv * u_resolution / (3.0 * u_dpr)) + 19.0);

      vec3 color = vec3(0.0);
      float alpha = 0.0;

      vec3 shadowColor = vec3(0.018, 0.025, 0.035);
      color += shadowColor * castShadow * 0.58;
      alpha += castShadow * 0.34;

      vec3 sootColor = vec3(0.035, 0.038, 0.047);
      color = mix(color, sootColor, clamp(charEdge * 0.9, 0.0, 1.0));
      alpha = max(alpha, charEdge * 0.88);

      vec3 ashColor = vec3(0.68, 0.67, 0.64);
      color = mix(color, ashColor, clamp(greyAsh * 0.78, 0.0, 1.0));
      alpha = max(alpha, greyAsh * 0.76);

      vec3 paperWhite = vec3(1.0, 0.995, 0.96);
      color = mix(
        color,
        paperWhite,
        clamp(whiteAsh + hotLine + chalkFuzz * 0.82, 0.0, 1.0)
      );
      alpha = max(
        alpha,
        clamp(whiteAsh * 0.94 + hotLine + chalkFuzz * 0.78, 0.0, 1.0)
      );

      vec3 fibreColor = mix(vec3(0.16, 0.17, 0.18), paperWhite, step(0.2, fibreTone));
      color = mix(color, fibreColor, fibreAmount);
      alpha = max(alpha, fibreAmount * mix(0.72, 0.98, step(0.2, fibreTone)));

      // Sparse, warm pinpricks keep the edge alive without turning it orange.
      vec2 sparkGrid = uv * u_resolution / (52.0 * u_dpr);
      vec2 sparkCell = floor(sparkGrid);
      vec2 sparkLocal = fract(sparkGrid) - 0.5;
      float sparkChance = hash21(sparkCell + 211.0);
      vec2 drift = vec2(
        hash21(sparkCell + 31.0) - 0.5,
        fract(hash21(sparkCell + 71.0) + u_time * 0.11) - 0.5
      );
      float spark = smoothstep(0.055, 0.0, length(sparkLocal - drift * 0.8));
      spark *= step(0.94, sparkChance)
        * smoothstep(-48.0 * px, -5.0 * px, d)
        * (1.0 - smoothstep(-5.0 * px, 0.0, d))
        * heat;
      color = mix(color, vec3(1.0, 0.79, 0.42), spark);
      alpha = max(alpha, spark * 0.84);

      alpha = clamp(alpha, 0.0, 1.0);
      outColor = vec4(color * alpha, alpha);
    }
  `;

  const fragmentSourceWebGL1 = fragmentSource
    .replace('#version 300 es', '')
    .replace('out vec4 outColor;', '')
    .replace('texture(u_edge', 'texture2D(u_edge')
    .replace('outColor =', 'gl_FragColor =');

  function compileShader(gl, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      const message = gl.getShaderInfoLog(shader);
      gl.deleteShader(shader);
      throw new Error(`Paper burn shader compilation failed: ${message}`);
    }
    return shader;
  }

  function createProgram(gl, isWebGL2) {
    const program = gl.createProgram();
    const vertex = compileShader(
      gl,
      gl.VERTEX_SHADER,
      isWebGL2 ? vertexSource : vertexSourceWebGL1,
    );
    const fragment = compileShader(
      gl,
      gl.FRAGMENT_SHADER,
      isWebGL2 ? fragmentSource : fragmentSourceWebGL1,
    );
    gl.attachShader(program, vertex);
    gl.attachShader(program, fragment);
    gl.linkProgram(program);
    gl.deleteShader(vertex);
    gl.deleteShader(fragment);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      const message = gl.getProgramInfoLog(program);
      gl.deleteProgram(program);
      throw new Error(`Paper burn shader link failed: ${message}`);
    }
    return program;
  }

  function hash(value) {
    const x = Math.sin(value * 127.1 + 311.7) * 43758.5453123;
    return x - Math.floor(x);
  }

  function smoothNoise(value, seed) {
    const lower = Math.floor(value);
    const fraction = value - lower;
    const eased = fraction * fraction * (3 - 2 * fraction);
    const start = hash(lower + seed * 1013);
    const end = hash(lower + 1 + seed * 1013);
    return ((start + (end - start) * eased) * 2) - 1;
  }

  function edgeY(width, height, x, progress) {
    const normalizedX = x / Math.max(width, 1);
    const scale = Math.min(1.2, Math.max(0.72, width / 920));
    const travel = progress * 0.72;
    const broad = smoothNoise(normalizedX * 5.2 + travel, 3) * 15;
    const medium = smoothNoise(normalizedX * 15.7 - travel * 1.3, 11) * 7;
    const fibres = smoothNoise(normalizedX * 48.0 + travel * 2.1, 29) * 4;
    const singe = smoothNoise(normalizedX * 113.0 - travel * 3.7, 47) * 1.8;
    const scallopNoise = smoothNoise(normalizedX * 22.0 + progress * 0.45, 67);
    const scallops = Math.pow(Math.max(0, scallopNoise), 2.4) * 11;
    const base = height - (height + 76) * progress;
    return (base + (broad + medium + fibres + singe + scallops) * scale) / height;
  }

  function mount(canvas, id) {
    if (instances.has(id)) dispose(id);
    const contextOptions = {
      alpha: true,
      antialias: false,
      depth: false,
      stencil: false,
      premultipliedAlpha: true,
      powerPreference: 'high-performance',
    };
    const webgl2 = canvas.getContext('webgl2', contextOptions);
    const gl = webgl2
      || canvas.getContext('webgl', contextOptions)
      || canvas.getContext('experimental-webgl', contextOptions);
    if (!gl) return;

    const program = createProgram(gl, Boolean(webgl2));
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 3, -1, -1, 3]),
      gl.STATIC_DRAW,
    );
    const position = gl.getAttribLocation(program, 'a_position');
    gl.enableVertexAttribArray(position);
    gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

    const edgeTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, edgeTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    const state = {
      canvas,
      gl,
      program,
      buffer,
      edgeTexture,
      edgeData: new Uint8Array(512 * 4),
      edgeSampleCount: 512,
      progress: 0,
      dpr: 1,
      cssWidth: 1,
      cssHeight: 1,
      resizeObserver: null,
      uniforms: {
        resolution: gl.getUniformLocation(program, 'u_resolution'),
        dpr: gl.getUniformLocation(program, 'u_dpr'),
        progress: gl.getUniformLocation(program, 'u_progress'),
        time: gl.getUniformLocation(program, 'u_time'),
        edge: gl.getUniformLocation(program, 'u_edge'),
      },
    };

    state.resizeObserver = new ResizeObserver(() => render(state));
    state.resizeObserver.observe(canvas);
    instances.set(id, state);
    render(state);
  }

  function resize(state) {
    const rect = state.canvas.getBoundingClientRect();
    state.cssWidth = Math.max(1, rect.width);
    state.cssHeight = Math.max(1, rect.height);
    state.dpr = Math.min(2, window.devicePixelRatio || 1);
    const width = Math.max(1, Math.round(state.cssWidth * state.dpr));
    const height = Math.max(1, Math.round(state.cssHeight * state.dpr));
    if (state.canvas.width !== width || state.canvas.height !== height) {
      state.canvas.width = width;
      state.canvas.height = height;
    }
    state.gl.viewport(0, 0, width, height);
  }

  function uploadEdge(state) {
    for (let index = 0; index < state.edgeSampleCount; index += 1) {
      const x = state.cssWidth * index / (state.edgeSampleCount - 1);
      const sample = edgeY(
        state.cssWidth,
        state.cssHeight,
        x,
        state.progress,
      );
      const offset = index * 4;
      state.edgeData[offset] = Math.round(Math.min(1, Math.max(0, sample)) * 255);
      state.edgeData[offset + 1] = 0;
      state.edgeData[offset + 2] = 0;
      state.edgeData[offset + 3] = 255;
    }
    const gl = state.gl;
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, state.edgeTexture);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      state.edgeSampleCount,
      1,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      state.edgeData,
    );
  }

  function render(state) {
    resize(state);
    uploadEdge(state);
    const gl = state.gl;
    gl.useProgram(state.program);
    gl.uniform2f(state.uniforms.resolution, state.canvas.width, state.canvas.height);
    gl.uniform1f(state.uniforms.dpr, state.dpr);
    gl.uniform1f(state.uniforms.progress, state.progress);
    gl.uniform1f(state.uniforms.time, performance.now() / 1000);
    gl.uniform1i(state.uniforms.edge, 0);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  function setProgress(id, progress) {
    const state = instances.get(id);
    if (!state) return;
    state.progress = Math.min(1, Math.max(0, Number(progress) || 0));
    render(state);
  }

  function dispose(id) {
    const state = instances.get(id);
    if (!state) return;
    state.resizeObserver.disconnect();
    state.gl.deleteTexture(state.edgeTexture);
    state.gl.deleteBuffer(state.buffer);
    state.gl.deleteProgram(state.program);
    instances.delete(id);
  }

  window.everafterPaperBurnSupported = function () {
    if (support !== undefined) return support;
    const probe = document.createElement('canvas');
    support = Boolean(
      probe.getContext('webgl2')
      || probe.getContext('webgl')
      || probe.getContext('experimental-webgl'),
    );
    return support;
  };
  window.everafterPaperBurnMount = mount;
  window.everafterPaperBurnSetProgress = setProgress;
  window.everafterPaperBurnDispose = dispose;
}());
