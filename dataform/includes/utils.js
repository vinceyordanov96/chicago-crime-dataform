function generate_surrogate_key(fields, default_null_value='null') {
    var sql = ``;
    for (let i = 0; i < fields.length; i++) {
        sql = sql + `coalesce(cast(${fields[i]} as string), '${default_null_value}')`;
        if (i < fields.length - 1) {
            sql = sql + ` || '-' || `;
        }
    }
    return `to_hex(md5(${sql}))`;
}

module.exports = { generate_surrogate_key }