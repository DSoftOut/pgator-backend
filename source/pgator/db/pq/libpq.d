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
public import dpq2;
import derelict.util.exception;
import dlogg.log;
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
    this(PGresult* result, shared ILogger plogger) nothrow
    {
        this.mResult = cast(shared)result;
        this.mLogger = plogger;
    }
    
    private shared PGresult* mResult;
    
    private PGresult* result() nothrow const
    {
        return cast(PGresult*)mResult;
    }
    
    private shared(ILogger) mLogger;
    
    protected shared(ILogger) logger()
    {
        return mLogger;
    }
    
    /**
    *   Prototype: PQresultStatus
    */
    ExecStatusType resultStatus() nothrow const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQresultStatus !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return PQresultStatus(result);
    }
    
    /**
    *   Prototype: PQresStatus
    *   Note: same as resultStatus, but converts 
    *         the enum to human-readable string.
    */
    string resStatus() const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQresultStatus !is null, "DerelictPQ isn't loaded!");
        assert(PQresStatus !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
    	return fromStringz(PQresStatus(PQresultStatus(result))).idup;
    }
    
    /**
    *   Prototype: PQresultErrorMessage
    */
    string resultErrorMessage() const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQresultErrorMessage !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return fromStringz(PQresultErrorMessage(result)).idup;
    }
    
    /**
    *   Prototype: PQclear
    */
    void clear() nothrow
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQclear !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        PQclear(result);
        mResult = null;
    }
    
    /**
    *   Prototype: PQntuples
    */
    size_t ntuples() nothrow const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQntuples !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return cast(size_t)PQntuples(result);
    }
    
    /**
    *   Prototype: PQnfields
    */
    size_t nfields() nothrow const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQnfields !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return cast(size_t)PQnfields(result);
    }
    
    /**
    *   Prototype: PQfname
    */ 
    string fname(size_t colNumber) const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQfname !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return enforceEx!Error(fromStringz(PQfname(result, cast(uint)colNumber)).idup);
    }
    
    /**
    *   Prototype: PQfformat
    */
    bool isBinary(size_t colNumber) const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQfformat !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return PQfformat(result, cast(uint)colNumber) == 1;
    }
    
    /**
    *   Prototype: PQgetvalue
    */
    string asString(size_t rowNumber, size_t colNumber) const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQgetvalue !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        import std.stdio; writeln(getLength(rowNumber, colNumber));
        return fromStringz(cast(immutable(char)*)PQgetvalue(result, cast(uint)rowNumber, cast(uint)colNumber));
    }
    
    /**
    *   Prototype: PQgetvalue
    */
    ubyte[] asBytes(size_t rowNumber, size_t colNumber) const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQgetvalue !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        auto l = getLength(rowNumber, colNumber);
        auto res = new ubyte[l];
        auto bytes = PQgetvalue(result, cast(uint)rowNumber, cast(uint)colNumber);
        foreach(i; 0..l)
            res[i] = bytes[i];
        return res;
    }
    
    /**
    *   Prototype: PQgetisnull
    */
    bool getisnull(size_t rowNumber, size_t colNumber) const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQgetisnull !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return PQgetisnull(result, cast(uint)rowNumber, cast(uint)colNumber) != 0;
    }
    
    /**
    *   Prototype: PQgetlength
    */
    size_t getLength(size_t rowNumber, size_t colNumber) const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQgetisnull !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return cast(size_t)PQgetlength(result, cast(uint)rowNumber, cast(uint)colNumber);
    }
    
    /**
    *   Prototype: PQftype
    */
    PQType ftype(size_t colNumber) const
    in
    {
        assert(result !is null, "PGconn was finished!");
        assert(PQftype !is null, "DerelictPQ isn't loaded!");
    }
    body
    {
        return cast(PQType)PQftype(result, cast(uint)colNumber);
    }
}

class CPGconn : IPGconn
{
    private Dpq2Connection conn;    
    private shared(ILogger) mLogger;

    this(Dpq2Connection conn, shared ILogger plogger) nothrow
    {
        this.conn = conn;
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

    void sendQueryParamsExt(string command, string[] paramValues)
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
