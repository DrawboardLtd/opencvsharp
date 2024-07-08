ARG DRAWBOARD_NUGET_FEED_ACCESSTOKEN
ARG OPENCV_VERSION=4.10.0

FROM mcr.microsoft.com/dotnet/runtime:8.0 as builder

ENV DEBIAN_FRONTEND=noninteractive

ARG OPENCV_VERSION
ENV OPENCV_VERSION=${OPENCV_VERSION}

WORKDIR /

##???
#libtbb-dev \
#libatlas-base-dev \

# GUI
# libgtk2.0-dev \

# Tesseract
#libtesseract-dev \

# Video
# libavcodec-dev \
# libavformat-dev \
# libswscale-dev \
# libdc1394-dev \
# libxine2-dev \
# libv4l-dev \
# libtheora-dev \
# libvorbis-dev \
# libxvidcore-dev \
# libopencore-amrnb-dev \
# libopencore-amrwb-dev \

# Install opencv dependencies
RUN apt-get update && apt-get -y install --no-install-recommends \
      apt-transport-https \
      software-properties-common \
      binutils-common \
      wget \
      unzip \
      build-essential \
      cmake \
      ninja-build \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

# Setup opencv and opencv-contrib source
RUN wget -q https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
    unzip -q ${OPENCV_VERSION}.zip && \
    rm ${OPENCV_VERSION}.zip && \
    mv opencv-${OPENCV_VERSION} opencv && \
    wget -q https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip && \
    unzip -q ${OPENCV_VERSION}.zip && \
    rm ${OPENCV_VERSION}.zip && \
    mv opencv_contrib-${OPENCV_VERSION} opencv_contrib

# Build OpenCV
RUN cd opencv && mkdir build && cd build && \
    cmake -GNinja \
    -D OPENCV_EXTRA_MODULES_PATH=/opencv_contrib/modules \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D BUILD_SHARED_LIBS=OFF \
    -D ENABLE_CXX11=ON \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_DOCS=OFF \
    -D BUILD_PERF_TESTS=OFF \
    -D BUILD_TESTS=OFF \
    -D BUILD_JAVA=OFF \
    -D BUILD_opencv_app=OFF \
    -D BUILD_opencv_barcode=OFF \
    -D BUILD_opencv_java_bindings_generator=OFF \
    -D BUILD_opencv_js_bindings_generator=OFF \
    -D BUILD_opencv_python_bindings_generator=OFF \
    -D BUILD_opencv_python_tests=OFF \
    -D BUILD_opencv_ts=OFF \
    -D BUILD_opencv_js=OFF \
    -D BUILD_opencv_bioinspired=OFF \
    -D BUILD_opencv_ccalib=OFF \
    -D BUILD_opencv_datasets=OFF \
    -D BUILD_opencv_dnn_objdetect=OFF \
    -D BUILD_opencv_dpm=OFF \
    -D BUILD_opencv_fuzzy=OFF \
    -D BUILD_opencv_gapi=OFF \
    -D BUILD_opencv_intensity_transform=OFF \
    -D BUILD_opencv_mcc=OFF \
    -D BUILD_opencv_objc_bindings_generator=OFF \
    -D BUILD_opencv_rapid=OFF \
    -D BUILD_opencv_reg=OFF \
    -D BUILD_opencv_stereo=OFF \
    -D BUILD_opencv_structured_light=OFF \
    -D BUILD_opencv_surface_matching=OFF \
    -D BUILD_opencv_videostab=OFF \
    -D BUILD_opencv_wechat_qrcode=ON \
    -D WITH_GSTREAMER=OFF \
    -D WITH_ADE=OFF \
    -D OPENCV_ENABLE_NONFREE=ON \
    .. && ninja && ninja install && ldconfig

# Install the Extern lib.
COPY src/ src/
RUN mkdir /nuget/ && mkdir /src/make && cd /src/make && \
    cmake -GNinja -D CMAKE_INSTALL_PREFIX=/src/make /src && \
    ninja && \
    cp /src/make/OpenCvSharpExtern/libOpenCvSharpExtern.so /nuget/

FROM mcr.microsoft.com/dotnet/sdk:8.0 as publisher

ARG DRAWBOARD_NUGET_FEED_ACCESSTOKEN
ENV DRAWBOARD_NUGET_FEED_ACCESSTOKEN=${DRAWBOARD_NUGET_FEED_ACCESSTOKEN}

ARG OPENCV_VERSION
ENV OPENCV_VERSION=${OPENCV_VERSION}

COPY nuget/ nuget/
COPY --from=builder /src/make/OpenCvSharpExtern/libOpenCvSharpExtern.so /nuget/
RUN dotnet nuget add source https://pkgs.dev.azure.com/drawboard/_packaging/Drawboard.Projects/nuget/v3/index.json \
        --name Drawboard.Projects --store-password-in-clear-text -u "ci@drawboard.com" -p "$DRAWBOARD_NUGET_FEED_ACCESSTOKEN" && \ 
    dotnet pack /nuget/OpenCvSharp4.runtime.linux-static-x64.csproj /p:Version=${OPENCV_VERSION} && \
    dotnet nuget push -s Drawboard.Projects -t 600 -k az --skip-duplicate /nuget/bin/Release/OpenCvSharp4.runtime.linux-static-x64.${OPENCV_VERSION}.nupkg
