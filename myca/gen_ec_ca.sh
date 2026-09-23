#!/bin/bash
set -e

CURVE="prime256v1"
ROOT_DAYS=36500
LEAF_DAYS=36500
ROOT_CN="MyEC Root CA"

# ========== 交互式输入域名 ==========
read -p "请输入证书域名(例如 kpanel.003.mtt.qzz.io): " LEAF_CN
LEAF_SAN="DNS:${LEAF_CN},IP:127.0.0.1"
TARGET_DIR="${LEAF_CN}"
echo ">> 域名: ${LEAF_CN}"
echo ">> SAN: ${LEAF_SAN}"
echo ">> 输出目录: ${TARGET_DIR}"

# 清理本次域名旧目录；根CA文件不动
rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

# ====================== 根CA：存在就跳过生成 ======================
if [ -f "root.key" ] && [ -f "root.crt" ];then
    echo "✅ 检测到已有 root.key + root.crt，跳过根CA生成"
else
    echo "🔐 未找到根CA，开始生成EC根证书..."
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:${CURVE} -out root.key

    # 根证书临时配置
    cat > root.tmp.conf <<EOF
[req]
distinguished_name = dn
x509_extensions = v3_ca
prompt = no
[dn]
C=CN
ST=Sichuan
L=Nanchong
O=MyEC RootCA
CN=${ROOT_CN}
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
EOF
    MSYS_NO_PATHCONV=1 openssl req -x509 -new -key root.key -sha256 -days ${ROOT_DAYS} \
        -config root.tmp.conf -out root.crt
    rm -f root.tmp.conf
    echo "✅ 根CA生成完成"
fi

# ====================== 叶子证书 ======================
cd "${TARGET_DIR}"
echo "🔐 生成叶子EC私钥"
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:${CURVE} -out server.key

echo "📄 生成CSR"
MSYS_NO_PATHCONV=1 openssl req -new -key server.key \
  -subj "/C=CN/ST=Sichuan/L=Nanchong/O=MyEC Site/CN=${LEAF_CN}" \
  -out server.csr

# 叶子扩展临时文件
cat > leaf_ext.tmp.conf <<EOF
subjectAltName = ${LEAF_SAN}
basicConstraints = critical,CA:FALSE
keyUsage = digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

echo "📜 CA签发叶子证书"
MSYS_NO_PATHCONV=1 openssl x509 -req -in server.csr \
  -CA ../root.crt -CAkey ../root.key -CAcreateserial \
  -days ${LEAF_DAYS} -sha256 \
  -extfile leaf_ext.tmp.conf \
  -out server.crt

rm -f leaf_ext.tmp.conf
cd ..

echo -e "\n🎉 全部完成！"
echo "根证书：root.crt  根私钥：root.key"
echo "叶子证书目录：${TARGET_DIR}/"
echo "校验命令：openssl x509 -in ${TARGET_DIR}/server.crt -text -noout"
echo "证书链验证：openssl verify -CAfile root.crt ${TARGET_DIR}/server.crt"
