"use strict";

const sexpr = require("./sexpr");

exports.Solver = class Solver {
    constructor(process) {
        this._callbackQueue = [];

        process.stdout.setEncoding("utf8");

        const parser = new sexpr.Parser();
        process.stdout.on("data", (data) => {
            parser.parse(data, (stmt) => {
                this._consume(stmt);
            });
        });

        this.process = process;
    }

    push(n) {
        this._send(["push", n.toString()]);
    }

    pop(n) {
        this._send(["pop", n.toString()]);
    }

    checkSat() {
        this._send(["check-sat"]);
        return this._getResponse();
    }

    declareConst(name, sort) {
        this._send(["declare-const", name, sort]);
    }

    assert(formula) {
        this._send(["assert", formula]);
    }

    getValue(vars) {
        this._send(["get-value", vars]);
        return this._getResponse();
    }

    getModel() {
        this._send(["get-model"]);
        return this._getResponse();
    }

    close() {
        this.process.stdin.end("(exit)");
    }

    _send(command) {
        const cmdString = sexpr.stringify(command);
        console.log(cmdString);
        this.process.stdin.write(cmdString + "\n");
    }

    _enqueueCallback(callback) {
        this._callbackQueue.push(callback);
    }

    _consume(stmt) {
        (this._callbackQueue.shift())(stmt);
    }

    _getResponse() {
        return new Promise((resolve, reject) => {
            this._enqueueCallback((stmt) => {
                if (stmt[0] !== "error") {
                    resolve(stmt);
                } else {
                    reject(stmt[1]);
                }
            });
        });
    }
};