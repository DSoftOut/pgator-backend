// Written in D programming language
/**
*   This module defines realization of high-level libpq api.
*
*   See_Also: pgator.db.pq.api
*
*   Copyright: © 2014 DSoftOut
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module pgator.db.pq.libpq;

public import pgator.db.pq.api;
import pgator.db.connection;
public import dpq2;
import derelict.util.exception;
import dlogg.log;
import vibe.data.bson;
import std.exception;
import std.string;
import std.regex;
import std.conv;
import core.memory;
import core.exception: RangeError;

alias Dpq2Connection = dpq2.Connection;
//import util;

synchronized class CPGresult : IPGresult
{
    private immutable Answer result;

    this(immutable Answer result, shared ILogger plogger) nothrow
    {
        this.result = result;
        this.mLogger = plogger;
    }

    Bson asColumnBson(shared IConnection conn) const
    {
        Bson[string] fields;
        foreach(i; 0..result.columnCount)
        {
            Bson[] rows;
            foreach(j; 0..result.length)
            {
                rows ~= result[j][i].toBson;
            }

            fields[result.columnName(i)] = Bson(rows);
        }

        return Bson(fields);
    }

    private shared(ILogger) mLogger;
    
    protected shared(ILogger) logger()
    {
        return mLogger;
    }

    ExecStatusType resultStatus() nothrow const
    {
        return result.status;
    }

    string resStatus() const
    {
        return result.statusString;
    }
    
    string resultErrorMessage() const
    {
        return result.resultErrorMessage;
    }
    
    size_t ntuples() nothrow const
    {
        return result.length;
    }
    
    size_t nfields() nothrow const
    {
        return result.columnCount;
    }
    
    string fname(size_t colNumber) const
    {
        return result.columnName(colNumber);
    }
    
    bool isBinary(size_t colNumber) const
    {
        return result.columnFormat(colNumber) == ValueFormat.BINARY;
    }

    string asString(size_t rowNumber, size_t colNumber) const
    {
        return result[rowNumber][colNumber].as!string;
    }

    ubyte[] asBytes(size_t rowNumber, size_t colNumber) const
    {
        return result[rowNumber][colNumber].as!PGbytea.dup;
    }

    bool getisnull(size_t rowNumber, size_t colNumber) const
    {
        return result[rowNumber].isNULL(colNumber);
    }

    OidType ftype(size_t colNumber) const
    {
        return result.OID(colNumber);
    }
}

synchronized class CPGconn : IPGconn
{
    private Dpq2Connection sharedConn;    
    private shared(ILogger) mLogger;

    @property
    Dpq2Connection conn() const nothrow // nonshared conn for compatibility with dpq2
    {
        return cast(Dpq2Connection) sharedConn;
    }

    this(Dpq2Connection conn, shared ILogger plogger) nothrow
    {
        this.sharedConn = cast(shared) conn;
        this.mLogger = plogger;
    }

    protected shared(ILogger) logger() nothrow
    {
        return mLogger;
    }

    PostgresPollingStatusType poll() nothrow
    {
        return conn.poll;
    }

    ConnStatusType status() nothrow
    {
        return conn.status;
    }

    /**
    *   Prototype: PQfinish
    *   Note: this function should be called even
    *   there was an error.
    */
    void finish() nothrow
    {
        conn.disconnect();
    }

    bool flush() nothrow const
    {
        return flush();
    }

    void resetStart()
    {
        conn.resetStart();
    }

    PostgresPollingStatusType resetPoll() nothrow
    {
        return conn.resetPoll();
    }

    string errorMessage() const nothrow @property
    {
        return conn.errorMessage();
    }

    void sendQuery(string command)
    {
        conn.sendQuery(command);
    }

    void sendQueryParams(string command, string[] paramValues)
    {
        QueryParams params;
        params.sqlCommand = command;
        params.resultFormat = ValueFormat.BINARY;
        params.args.length = paramValues.length;

        foreach(i, ref p; params.args)
        {
            p.value = paramValues[i];
        }

        conn.sendQuery(params);
    }

    /**
    *   Like sendQueryParams but uses libpq escaping functions
    *   and sendQuery. 
    *   
    *   The main advantage of the function is ability to handle
    *   multiple SQL commands in one query.
    *   Throws: PGQueryException
    */
    void sendQueryParamsExt(string command, string[] paramValues)
    {
        sendQuery(escapeParams(command, paramValues));
    }

    /**
    *   Prototype: PQgetResult
    *   Note: Even when PQresultStatus indicates a fatal error, 
    *         PQgetResult should be called until it returns a null pointer 
    *         to allow libpq to process the error information completely.
    *   Note: A null pointer is returned when the command is complete and t
    *         here will be no more results.
    */
    shared(IPGresult) getResult()
    {
        auto r = conn.getAnswer();

        if(r is null) return null;

        return new shared CPGresult(r, logger);
    }

    void consumeInput()
    {
        conn.consumeInput();
    }

    bool isBusy() nothrow
    {
        return conn.isBusy();
    }
    
    /**
    *   Prototype: PQescapeLiteral
    *   Throws: PGEscapeException
    */
    string escapeLiteral(string msg)
    {
        return conn.escapeLiteral(msg);
    }
    
    /**
    *   Escaping query like PQexecParams does. This function
    *   enables use of multiple SQL commands in one query.
    */
    private string escapeParams(string query, string[] args)
    {
        foreach(i, arg; args)
        {
            auto reg = regex(text(`\$`, i));
            query = query.replaceAll(reg, escapeLiteral(arg));
        }
        return query;
    }

    string parameterStatus(string param)
    {
        return conn.parameterStatus(param);
    }

    /**
    *   Prototype: PQsetNoticeProcessor
    */
    PQnoticeProcessor setNoticeProcessor(PQnoticeProcessor proc, void* arg) nothrow
    {
        return conn.setNoticeProcessor(proc, arg);
    }

    string server()
    {
        return conn.host;
    }
}

synchronized class PostgreSQL : IPostgreSQL
{
    this(shared ILogger plogger)
    {
        this.mLogger = plogger;
        initialize();
    }

    private shared(ILogger) mLogger;
    
    protected shared(ILogger) logger()
    {
        return mLogger;
    }
    
    /**
    *   Should be called to free libpq resources. The method
    *   unloads library from application memory.
    */
    void finalize() nothrow
    {
        /*
        try
        {
        	GC.collect();
        	DerelictPQ.unload();
    	} catch(Throwable th)
        {
        	
        }
        */
    }
    
    shared(IPGconn) startConnect(string conninfo)
    {
        auto c = new Connection;
        c.connString = conninfo;
        c.connectNonblockingStart();

        return new shared CPGconn(c, logger);
    }
    
    /**
    *   Prototype: PQping
    */
    PGPing ping(string conninfo) nothrow
    in
    {
        assert(PQping !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return PQping(cast(char*)conninfo.toStringz);
    }
    
    protected
    {
        /**
        *   Should be called in class constructor. The method
        *   loads library in memory.
        */
        void initialize()
        {
            try
            {
                version(linux)
                {
                    try
                    {
                        DerelictPQ.load();
                    } catch(DerelictException e)
                    {
                        // try with some frequently names
                        DerelictPQ.load("libpq.so.0,libpq.so.5");
                    }
                }
                else
                {
                    DerelictPQ.load();
                }
            } catch(SymbolLoadException e)
            {
                if( e.symbolName != "PQconninfo" &&
                    e.symbolName != "PQsetSingleRowMode")
                {
                    throw e;
                }
            }
        }
    }
}
